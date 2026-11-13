import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

enum DiagnosticProvider { cue, anilist, mal, local }

enum DiagnosticOperation {
  discover,
  search,
  title,
  match,
  aliases,
  import,
  settings,
  mood,
}

enum DiagnosticStatus { ok, unavailable, rejected, failed }

enum DiagnosticError {
  none('none'),
  network('network'),
  http4xx('http_4xx'),
  http5xx('http_5xx'),
  rateLimited('rate_limited'),
  notConfigured('not_configured'),
  invalidResponse('invalid_response'),
  storageFailed('storage_failed');

  const DiagnosticError(this.code);
  final String code;
}

const diagnosticAppVersion =
    '${String.fromEnvironment('FLUTTER_BUILD_NAME', defaultValue: '0.0.1')}+${String.fromEnvironment('FLUTTER_BUILD_NUMBER', defaultValue: '1')}';

abstract class DiagnosticConsentStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureDiagnosticConsentStore implements DiagnosticConsentStore {
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: 'cue_technical_diagnostics');
  @override
  Future<void> write(String value) =>
      _storage.write(key: 'cue_technical_diagnostics', value: value);
}

String _requestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class DiagnosticTicket {
  DiagnosticTicket(this.epoch, this.provider, this.operation)
    : watch = Stopwatch()..start();
  final int epoch;
  final DiagnosticProvider provider;
  final DiagnosticOperation operation;
  final Stopwatch watch;
}

/// No request content enters this service. Consent and capability are device-local
/// secure storage, not profile settings, backups or sync.
class TechnicalDiagnostics extends ChangeNotifier {
  TechnicalDiagnostics(
    this.base,
    this.store, {
    http.Client Function()? clientFactory,
    DateTime Function()? clock,
  }) : _clientFactory = clientFactory ?? (() => http.Client()),
       _now = clock ?? DateTime.now;
  final String base;
  final DiagnosticConsentStore store;
  final http.Client Function() _clientFactory;
  final DateTime Function() _now;
  Future<void> _saveTail = Future<void>.value();
  final _pending = <Map<String, Object>>[];
  bool enabled = false;
  bool loaded = false;
  bool sending = false;
  bool changing = false;
  bool _disposed = false;
  int _epoch = 0;
  String? _code;
  int? _expiresAt;
  String? message;
  Timer? _timer;
  http.Client? _uploadClient;
  int get pendingCount => _pending.length;
  String? get recoveryCode => _code;
  DateTime? get expiresAt => _expiresAt == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(_expiresAt!, isUtc: true);
  String? get sessionId =>
      _code == null ? null : sha256.convert(utf8.encode(_code!)).toString();

  Future<void> load() async {
    try {
      final raw = await store.read();
      if (raw != null) {
        final json = jsonDecode(raw) as Map;
        final code = json['token'];
        final expiry = json['expiresAt'];
        if (json['enabled'] is! bool ||
            (json['version'] != null && json['version'] != 2) ||
            (json['version'] == null && !_validToken(code)) ||
            (json['version'] == 2 &&
                ((code == null) != (expiry == null) ||
                    (code != null &&
                        (!_validToken(code) ||
                            expiry is! int ||
                            expiry <= 0))))) {
          throw const FormatException('Invalid consent record');
        }
        // Legacy client-generated capabilities are never used to open a session.
        final reusable =
            json['version'] == 2 &&
            code != null &&
            (expiry as int) > _now().millisecondsSinceEpoch;
        final epoch = _epoch;
        final nextCode = reusable ? code as String : null;
        final nextExpiry = reusable ? expiry : null;
        if (!await _persist(
              epoch,
              json['enabled'] as bool,
              nextCode,
              nextExpiry,
            ) ||
            _disposed ||
            epoch != _epoch) {
          return;
        }
        _code = nextCode;
        _expiresAt = nextExpiry;
        enabled = json['enabled'] as bool;
      }
    } on Object {
      message = 'Could not read diagnostics consent. Collection stays off.';
    } finally {
      loaded = true;
      _changed();
    }
  }

  Future<void> setEnabled(bool value) async {
    if (!loaded) throw StateError('Consent not loaded');
    if (changing) throw StateError('Consent change already in progress');
    changing = true;
    // Stop locally before persisting OFF, even if secure storage fails.
    _epoch++;
    enabled = false;
    _timer?.cancel();
    _pending.clear();
    _uploadClient?.close();
    _uploadClient = null;
    _changed();
    final epoch = _epoch;
    try {
      final code = value ? null : _code;
      final expiry = value ? null : _expiresAt;
      if (!await _persist(epoch, value, code, expiry) ||
          _disposed ||
          epoch != _epoch) {
        return;
      }
      _code = code;
      _expiresAt = expiry;
      enabled = value;
      message = value
          ? 'Technical diagnostics on. Only new requests are collected. A new private code is issued after the first upload.'
          : 'Diagnostics off. Pending events discarded; already uploaded records expire after 7 days.';
    } on Object {
      message = 'Could not save diagnostics consent. Collection is off.';
      rethrow;
    } finally {
      changing = false;
      _changed();
    }
  }

  /// Stops future uploads to a shared code, without deleting its retained logs.
  Future<void> startNewSession() async {
    if (!enabled) throw StateError('Diagnostics is off');
    await setEnabled(true);
  }

  bool _validToken(Object? code) =>
      code is String &&
      RegExp(r'^[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]$').hasMatch(code);

  Future<bool> _persist(
    int epoch,
    bool consent,
    String? code,
    int? expiry,
  ) async {
    final previous = _saveTail;
    final done = Completer<void>();
    _saveTail = done.future;
    try {
      await previous;
      if (_disposed || epoch != _epoch) return false;
      await store.write(
        jsonEncode({
          'version': 2,
          'enabled': consent,
          'token': code,
          'expiresAt': expiry,
        }),
      );
      return !_disposed && epoch == _epoch;
    } finally {
      done.complete();
    }
  }

  DiagnosticTicket? begin(
    DiagnosticProvider provider,
    DiagnosticOperation operation,
  ) => enabled && loaded && !_disposed
      ? DiagnosticTicket(_epoch, provider, operation)
      : null;

  void finish(
    DiagnosticTicket? ticket,
    DiagnosticStatus status,
    DiagnosticError error,
  ) {
    if (ticket == null) return;
    _record(
      ticket.epoch,
      ticket.provider,
      ticket.operation,
      ticket.watch.elapsedMilliseconds,
      status,
      error,
    );
  }

  /// A response whose headers said 200 but whose body was unusable (GraphQL
  /// `errors`, not JSON). [DiagnosticHttpClient] only sees headers and has
  /// already counted the request as ok; the caller that parsed the body
  /// reports this as one extra `failed` / `invalid_response` event with
  /// duration 0, so the timing stays header-time. Nothing about the body
  /// is recorded.
  void reportInvalid(
    DiagnosticProvider provider,
    DiagnosticOperation operation,
  ) {
    if (!enabled || !loaded) return;
    _record(
      _epoch,
      provider,
      operation,
      0,
      DiagnosticStatus.failed,
      DiagnosticError.invalidResponse,
    );
  }

  void _record(
    int epoch,
    DiagnosticProvider provider,
    DiagnosticOperation operation,
    int durationMs,
    DiagnosticStatus status,
    DiagnosticError error,
  ) {
    if (!enabled || _disposed || epoch != _epoch) return;
    if (_pending.length == 20) {
      message = 'Diagnostics pending limit reached. New event not collected; retry upload or turn off.';
      _changed();
      return;
    }
    _pending.add({
      'requestId': _requestId(),
      'appVersion': diagnosticAppVersion,
      'provider': provider.name,
      'operation': operation.name,
      'durationMs': durationMs.clamp(0, 120000),
      'status': status.name,
      'errorCode': error.code,
    });
    _timer ??= Timer(const Duration(seconds: 5), () {
      _timer = null;
      unawaited(upload());
    });
    _changed();
  }

  Future<void> upload() async {
    if (!enabled || sending || _disposed || _pending.isEmpty) return;
    _timer?.cancel();
    _timer = null;
    final epoch = _epoch;
    final batch = List<Map<String, Object>>.of(_pending);
    sending = true;
    final client = _clientFactory();
    _uploadClient = client;
    _changed();
    var savingSession = false;
    try {
      var code = _code;
      if (_expiresAt != null && _now().millisecondsSinceEpoch >= _expiresAt!) {
        code = null;
      }
      Future<bool> retire() async {
        savingSession = true;
        if (!await _persist(epoch, true, null, null) ||
            _disposed ||
            epoch != _epoch) {
          return false;
        }
        _code = null;
        _expiresAt = null;
        savingSession = false;
        return true;
      }

      if (code == null && _code != null && !await retire()) return;
      if (epoch != _epoch || _disposed || !enabled) return;
      Future<http.Response> send(String? capability) {
        final body = jsonEncode({'events': batch});
        if (capability == null) {
          return client
              .post(
                Uri.parse('$base/diagnostics'),
                headers: {'Content-Type': 'application/json'},
                body: body,
              )
              .timeout(const Duration(seconds: 15));
        }
        final id = sha256.convert(utf8.encode(capability)).toString();
        return client
            .put(
              Uri.parse('$base/diagnostics/$id'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $capability',
              },
              body: body,
            )
            .timeout(const Duration(seconds: 15));
      }

      var response = await send(code);
      if (epoch != _epoch || _disposed) return;
      // The server is authoritative even when the device clock moves
      // backwards: a 404 means the session is gone. A full session (100
      // events) answers quota_exceeded; its code is retired too, so new
      // events go to a fresh session instead of stalling. This happens at
      // most once per upload: the POST below is never followed by another,
      // and a POST refused for quota (the global session cap) just reports.
      var rolledOver = false;
      if (code != null &&
          (response.statusCode == 404 || _quotaExceeded(response))) {
        rolledOver = response.statusCode != 404;
        code = null;
        if (!await retire()) return;
        if (epoch != _epoch || _disposed || !enabled) return;
        response = await send(null);
      }
      if (epoch != _epoch || _disposed) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        message = response.statusCode == 429
            ? 'Diagnostics quota or rate limit reached. Retry later.'
            : 'Diagnostics unavailable (HTTP ${response.statusCode}). No success claimed; retry later.';
      } else {
        final body = jsonDecode(response.body);
        if (body is! Map ||
            body.keys.length != (code == null ? 3 : 2) ||
            !body.keys.toSet().containsAll({
              'accepted',
              'expiresAt',
              if (code == null) 'token',
            }) ||
            body['expiresAt'] is! int ||
            (body['expiresAt'] as int) <= 0 ||
            (code == null && !_validToken(body['token'])) ||
            (code == null && body['accepted'] != batch.length) ||
            (code != null && body['expiresAt'] != _expiresAt) ||
            body['accepted'] is! int ||
            (body['accepted'] as int) < 0 ||
            (body['accepted'] as int) > batch.length) {
          throw const FormatException('Invalid acknowledgement');
        }
        if (code == null) {
          savingSession = true;
          final newCode = body['token'] as String;
          final expiry = body['expiresAt'] as int;
          if (!await _persist(epoch, true, newCode, expiry) ||
              _disposed ||
              epoch != _epoch) {
            return;
          }
          _code = newCode;
          _expiresAt = expiry;
          savingSession = false;
        }
        final ids = batch.map((e) => e['requestId']).toSet();
        _pending.removeWhere((e) => ids.contains(e['requestId']));
        message = rolledOver
            ? 'The previous diagnostics session was full; a new private code was issued. Up to 100 events per seven-day session.'
            : 'Technical diagnostics uploaded. Up to 100 events per seven-day session.';
      }
    } on Object {
      if (epoch == _epoch && !_disposed) {
        if (savingSession) {
          enabled = false;
          _epoch++;
          _pending.clear();
          _timer?.cancel();
          message = 'Could not save the new diagnostics session. Collection is off; retry consent before collecting more.';
        } else {
          message = 'Diagnostics upload failed. Retry later; no request content was logged.';
        }
      }
    } finally {
      client.close();
      if (identical(_uploadClient, client)) _uploadClient = null;
      sending = false;
      _changed();
    }
  }

  /// 429 `quota_exceeded`, as opposed to a plain `rate_limited` (retry later
  /// with the same code). Only the fixed error code is read.
  static bool _quotaExceeded(http.Response response) {
    if (response.statusCode != 429) return false;
    try {
      final body = jsonDecode(response.body);
      return body is Map && body['error'] == 'quota_exceeded';
    } on FormatException {
      return false;
    }
  }

  /// Explicit user action; never exports the recovery code with the logs.
  Future<String> export() async {
    final code = _code;
    final epoch = _epoch;
    if (code == null) throw StateError('No diagnostics session');
    final id = sha256.convert(utf8.encode(code)).toString();
    final client = _clientFactory();
    try {
      final response = await client
          .get(
            Uri.parse('$base/diagnostics/$id'),
            headers: {'Authorization': 'Bearer $code'},
          )
          .timeout(const Duration(seconds: 15));
      if (_disposed || epoch != _epoch) {
        throw StateError('Diagnostics session changed');
      }
      if (response.statusCode != 200) {
        throw StateError('Diagnostics export unavailable');
      }
      final decoded = jsonDecode(response.body);
      // Server validates data; an export must still be an event document.
      if (decoded is! Map ||
          decoded.keys.length != 1 ||
          decoded['events'] is! List) {
        throw const FormatException('Invalid diagnostics export');
      }
      final events = decoded['events'] as List;
      if (events.length > 100 || events.any((e) => !_validEvent(e))) {
        throw const FormatException('Invalid diagnostics events');
      }
      return jsonEncode({'events': decoded['events']});
    } finally {
      client.close();
    }
  }

  bool _validEvent(Object? event) {
    if (event is! Map || event.length != 7) return false;
    return event.keys.toSet().containsAll({
          'requestId',
          'appVersion',
          'provider',
          'operation',
          'durationMs',
          'status',
          'errorCode',
        }) &&
        event['requestId'] is String &&
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(event['requestId'] as String) &&
        event['appVersion'] is String &&
        (event['appVersion'] as String).length <= 32 &&
        RegExp(r'^\d+\.\d+\.\d+(?:\+\d+)?$')
            .hasMatch(event['appVersion'] as String) &&
        DiagnosticProvider.values.any((v) => v.name == event['provider']) &&
        DiagnosticOperation.values.any((v) => v.name == event['operation']) &&
        DiagnosticStatus.values.any((v) => v.name == event['status']) &&
        DiagnosticError.values.any((v) => v.code == event['errorCode']) &&
        event['durationMs'] is int &&
        (event['durationMs'] as int) >= 0 &&
        (event['durationMs'] as int) <= 120000;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    enabled = false;
    _epoch++;
    _timer?.cancel();
    _pending.clear();
    _uploadClient?.close();
    super.dispose();
  }
}

/// Request header naming the operation of an AniList request (a
/// [DiagnosticOperation] name). Set by the AniList client, read and removed
/// by [DiagnosticHttpClient] before sending: AniList never receives it.
const diagnosticOperationHeader = 'X-Cue-Op';

/// Measures only request-to-response-header timing and allowlisted HTTP status.
/// Never reads body, search text or URL into a diagnostic event; the only
/// header read is [diagnosticOperationHeader], a fixed enum name.
class DiagnosticHttpClient extends http.BaseClient {
  DiagnosticHttpClient(this.inner, this.diagnostics, {this.anilist = false});
  final http.Client inner;
  final TechnicalDiagnostics diagnostics;
  final bool anilist;

  DiagnosticOperation? _operation(Uri uri, String? tagged) {
    if (anilist) {
      // AniList has one endpoint; the client tags each request instead.
      for (final op in DiagnosticOperation.values) {
        if (op.name == tagged) return op;
      }
      return DiagnosticOperation.match;
    }
    final parts = uri.pathSegments;
    if (parts.isEmpty) return null;
    if (parts.length == 2 && parts.first == 'ai') {
      return switch (parts[1]) {
        'mood' || 'recommend' => DiagnosticOperation.mood,
        _ => null,
      };
    }
    if (parts.first == 'import' || parts.first == 'oauth') {
      return DiagnosticOperation.import;
    }
    // /sync, /diagnostics and /catalog/image are never recorded.
    if (parts.length < 2 || parts.first != 'catalog') return null;
    return switch (parts[1]) {
      'discover' || 'recommendations' => DiagnosticOperation.discover,
      'search' => DiagnosticOperation.search,
      'title' => DiagnosticOperation.title,
      'match' => DiagnosticOperation.match,
      'aliases' || 'mal-search' || 'names' => DiagnosticOperation.aliases,
      _ => null,
    };
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final op = _operation(
      request.url,
      request.headers.remove(diagnosticOperationHeader),
    );
    final ticket = op == null
        ? null
        : diagnostics.begin(
            anilist ? DiagnosticProvider.anilist : DiagnosticProvider.cue,
            op,
          );
    try {
      final response = await inner.send(request);
      final status = response.statusCode;
      diagnostics.finish(
        ticket,
        status < 400
            ? DiagnosticStatus.ok
            : status >= 500
            ? DiagnosticStatus.unavailable
            : DiagnosticStatus.rejected,
        status < 400
            ? DiagnosticError.none
            : status == 429
            ? DiagnosticError.rateLimited
            : status == 503
            ? DiagnosticError.http5xx
            : status >= 500
            ? DiagnosticError.http5xx
            : DiagnosticError.http4xx,
      );
      return response;
    } on Object {
      diagnostics.finish(
        ticket,
        DiagnosticStatus.unavailable,
        DiagnosticError.network,
      );
      rethrow;
    }
  }

  @override
  void close() => inner.close();
}
