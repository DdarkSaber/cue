import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../data/backup_service.dart';
import '../data/db/database.dart';
import '../data/library_repository.dart';
import '../data/profile_repository.dart';
import '../imports/import_service.dart';
import 'sync_crypto.dart';
import 'sync_merge.dart';

/// Where the sync code is kept: platform secure storage (Keystore,
/// Keychain; WebCrypto-wrapped storage on the web).
abstract class CodeStore {
  Future<String?> read(String profileId);
  Future<void> write(String profileId, String code);
  Future<void> delete(String profileId);
}

class SecureCodeStore implements CodeStore {
  const SecureCodeStore();
  static const _storage = FlutterSecureStorage();
  String _key(String p) => 'cue_sync_code_$p';

  @override
  Future<String?> read(String profileId) => _storage.read(key: _key(profileId));
  @override
  Future<void> write(String profileId, String code) =>
      _storage.write(key: _key(profileId), value: code);
  @override
  Future<void> delete(String profileId) =>
      _storage.delete(key: _key(profileId));
}

class MemoryCodeStore implements CodeStore {
  final _codes = <String, String>{};
  @override
  Future<String?> read(String profileId) async => _codes[profileId];
  @override
  Future<void> write(String profileId, String code) async =>
      _codes[profileId] = code;
  @override
  Future<void> delete(String profileId) async => _codes.remove(profileId);
}

/// Talks to the Worker's /sync routes. Only ids, tokens and ciphertext.
abstract class SyncRemote {
  Future<({int version, String data})?> get(String id, String token);

  /// Returns the new version, or throws [SyncConflict].
  Future<int> put(String id, String token, int expected, String data);
  Future<void> delete(String id, String token);
}

class SyncConflict implements Exception {
  const SyncConflict(this.version);
  final int version;
}

class SyncFailed implements Exception {
  const SyncFailed(this.code);
  final String code;
}

class HttpSyncRemote implements SyncRemote {
  HttpSyncRemote(this.base, {http.Client? client})
    : _client = client ?? http.Client();
  final String base;
  final http.Client _client;

  Future<http.Response> _send(
    String method,
    String id,
    String token, [
    Object? body,
  ]) async {
    final req = http.Request(method, Uri.parse('$base/sync/$id'))
      ..headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    try {
      return await http.Response.fromStream(
        await _client.send(req).timeout(const Duration(seconds: 30)),
      );
    } on Object {
      throw const SyncFailed('offline');
    }
  }

  Map<String, dynamic> _json(http.Response r) =>
      Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map);

  /// The failure for a non-200 answer. Storage full (429 quota_exceeded)
  /// is `quota`; anything else keeps its HTTP status.
  static SyncFailed _failure(http.Response r) {
    if (r.statusCode == 429) {
      try {
        final b = jsonDecode(utf8.decode(r.bodyBytes));
        if (b is Map && b['error'] == 'quota_exceeded') {
          return const SyncFailed('quota');
        }
      } on FormatException {
        // Not the Worker's JSON: fall through to the status.
      }
    }
    return SyncFailed('http_${r.statusCode}');
  }

  @override
  Future<({int version, String data})?> get(String id, String token) async {
    final r = await _send('GET', id, token);
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw _failure(r);
    final j = _json(r);
    return (version: (j['version'] as num).toInt(), data: j['data'] as String);
  }

  @override
  Future<int> put(String id, String token, int expected, String data) async {
    final r = await _send('PUT', id, token, {
      'version': expected,
      'data': data,
    });
    if (r.statusCode == 409) {
      throw SyncConflict((_json(r)['version'] as num).toInt());
    }
    if (r.statusCode != 200) throw _failure(r);
    return (_json(r)['version'] as num).toInt();
  }

  @override
  Future<void> delete(String id, String token) async {
    final r = await _send('DELETE', id, token);
    if (r.statusCode != 200 && r.statusCode != 404) {
      throw _failure(r);
    }
  }
}

class SyncResult {
  const SyncResult({
    required this.version,
    required this.pulled,
    required this.pushed,
    this.moodChanged = false,
  });
  final int version;

  /// Titles added or changed here from the other devices.
  final int pulled;
  final bool pushed;

  /// The other device's mood learning replaced this one's.
  final bool moodChanged;
}

/// End-to-end encrypted sync of one library. A merge imports the other
/// copy, then settles each title by its last edit, and each list, the
/// library settings and mood learning by when that part last changed
/// (so removals travel too).
class SyncService {
  SyncService({
    required this.remote,
    required this.codes,
    required this.backup,
    required this.imports,
    required this.profiles,
    required this.library,
    required this.db,
  });

  final SyncRemote remote;
  final CodeStore codes;
  final BackupService backup;
  final ImportService imports;
  final ProfileRepository profiles;
  final LibraryRepository library;
  final CueDatabase db;

  late final _m = SyncMerge(
    db: db,
    profiles: profiles,
    imports: imports,
    library: library,
    backup: backup,
  );

  static const _versionKey = 'syncVersion';
  static const _lastKey = 'syncLast';

  Future<String?> code(String profileId) => codes.read(profileId);

  Future<DateTime?> lastSynced(String profileId) async {
    final raw = await profiles.rawSetting(profileId, _lastKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Turns sync on with a new code and uploads this library.
  Future<String> enable(String profileId) async {
    final code = newSyncCode();
    await codes.write(profileId, normalizeSyncCode(code)!);
    await profiles.setRawSetting(profileId, _versionKey, '0');
    await syncNow(profileId);
    return code;
  }

  /// Joins an existing sync from another device; merges both ways.
  Future<SyncResult> join(String profileId, String input) async {
    final code = normalizeSyncCode(input);
    if (code == null) throw const SyncFailed('bad_code');
    final keys = await deriveSyncKeys(code);
    final existing = await remote.get(keys.id, keys.token);
    if (existing == null) throw const SyncFailed('no_copy');
    // Opening proves the code is right before anything is saved.
    await openBlob(existing.data, keys.key);
    await codes.write(profileId, code);
    await profiles.setRawSetting(profileId, _versionKey, '0');
    return syncNow(profileId);
  }

  /// Pull, merge, push. Retries once if another device wrote in between.
  Future<SyncResult> syncNow(String profileId) async {
    final code = await codes.read(profileId);
    if (code == null) throw const SyncFailed('off');
    final keys = await deriveSyncKeys(code);
    var pulled = 0;
    var moodChanged = false;
    for (var attempt = 0; attempt < 3; attempt++) {
      await _m.stampChangedSections(profileId);
      final current = await remote.get(keys.id, keys.token);
      var base = 0;
      if (current != null) {
        base = current.version;
        final known =
            int.tryParse(
              await profiles.rawSetting(profileId, _versionKey) ?? '',
            ) ??
            0;
        if (current.version != known) {
          final remoteJson = await openBlob(current.data, keys.key);
          pulled += await _m.merge(profileId, remoteJson);
          moodChanged |= await _m.mergeSections(profileId, remoteJson);
        }
      }
      final json = await _m.exportWithSections(profileId);
      final sealed = await sealBlob(json, keys.key);
      try {
        final v = await remote.put(keys.id, keys.token, base, sealed);
        await profiles.setRawSetting(profileId, _versionKey, '$v');
        await profiles.setRawSetting(
          profileId,
          _lastKey,
          DateTime.now().toUtc().toIso8601String(),
        );
        return SyncResult(
          version: v,
          pulled: pulled,
          pushed: true,
          moodChanged: moodChanged,
        );
      } on SyncConflict {
        continue;
      }
    }
    throw const SyncFailed('busy');
  }

  /// Stops syncing on this device. The encrypted copy stays for others.
  Future<void> disable(String profileId) async {
    await codes.delete(profileId);
    await profiles.setRawSetting(profileId, _versionKey, null);
  }

  /// Deletes the encrypted copy from the Worker, then turns sync off here.
  Future<void> deleteRemote(String profileId) async {
    final code = await codes.read(profileId);
    if (code != null) {
      final keys = await deriveSyncKeys(code);
      await remote.delete(keys.id, keys.token);
    }
    await disable(profileId);
  }
}
