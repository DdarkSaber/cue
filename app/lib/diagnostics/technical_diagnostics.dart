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

String _token() =>
    base64UrlEncode(List.generate(32, (_) => Random.secure().nextInt(256)))
        .replaceAll('=', '');
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
  }) : _clientFactory = clientFactory ?? (() => http.Client());
  final String base;
  final DiagnosticConsentStore store;
  final http.Client Function() _clientFactory;
  final _pending = <Map<String, Object>>[];
  bool enabled = false;
  bool loaded = false;
  bool sending = false;
  bool changing = false;
  bool _disposed = false;
  int _epoch = 0;
  String? _code;
  String? message;
  Timer? _timer;
  http.Client? _uploadClient;
  int get pendingCount => _pending.length;
  String? get recoveryCode => _code;
  String? get sessionId =>
      _code == null ? null : sha256.convert(utf8.encode(_code!)).toString();

  Future<void> load() async {
    try {
      final raw = await store.read();
      if (raw != null) {
        final json = jsonDecode(raw) as Map;
        final code = json['token'];
        if (code is! String ||
            !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(code) ||
            json['enabled'] is! bool) {
          throw const FormatException('Invalid consent record');
        }
        _code = code;
        if (!_disposed) enabled = json['enabled'] as bool;
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
    _code ??= _token();
    try {
      await store.write(jsonEncode({'enabled': value, 'token': _code}));
      if (!_disposed) enabled = value;
      message = value
          ? 'Technical diagnostics on. Only new requests are collected.'
          : 'Diagnostics off. Pending events discarded; already uploaded records expire after 7 days.';
    } on Object {
      message = 'Could not save diagnostics consent. Collection is off.';
      rethrow;
    } finally {
      changing = false;
      _changed();
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
    if (ticket == null || !enabled || _disposed || ticket.epoch != _epoch) {
      return;
    }
    if (_pending.length == 20) {
      message = 'Diagnostics pending limit reached. New event not collected; retry upload or turn off.';
      _changed();
      return;
    }
    _pending.add({
      'requestId': _requestId(),
      'appVersion': diagnosticAppVersion,
      'provider': ticket.provider.name,
      'operation': ticket.operation.name,
      'durationMs': ticket.watch.elapsedMilliseconds.clamp(0, 120000),
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
    try {
      final response = await client
          .put(
            Uri.parse('$base/diagnostics/$sessionId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_code',
            },
            body: jsonEncode({'events': batch}),
          )
          .timeout(const Duration(seconds: 15));
      if (epoch != _epoch || _disposed) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        message = response.statusCode == 429
            ? 'Diagnostics quota or rate limit reached. Retry later.'
            : 'Diagnostics unavailable (HTTP ${response.statusCode}). No success claimed; retry later.';
      } else {
        final body = jsonDecode(response.body);
        if (body is! Map ||
            body.keys.length != 1 ||
            body['accepted'] is! int ||
            (body['accepted'] as int) < 0 ||
            (body['accepted'] as int) > batch.length) {
          throw const FormatException('Invalid acknowledgement');
        }
        final ids = batch.map((e) => e['requestId']).toSet();
        _pending.removeWhere((e) => ids.contains(e['requestId']));
        message = 'Technical diagnostics uploaded. Up to 100 events per seven-day session.';
      }
    } on Object {
      if (epoch == _epoch && !_disposed) message = 'Diagnostics upload failed. Retry later; no request content was logged.';
    } finally {
      client.close();
      if (identical(_uploadClient, client)) _uploadClient = null;
      sending = false;
      _changed();
    }
  }

  /// Explicit user action; never exports the recovery code with the logs.
  Future<String> export() async {
    if (_code == null) throw StateError('No diagnostics session');
    final client = _clientFactory();
    try {
      final response = await client
          .get(
            Uri.parse('$base/diagnostics/$sessionId'),
            headers: {'Authorization': 'Bearer $_code'},
          )
          .timeout(const Duration(seconds: 15));
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

/// Measures only request-to-response-header timing and allowlisted HTTP status.
/// Never reads body, headers, search text or URL into a diagnostic event.
class DiagnosticHttpClient extends http.BaseClient {
  DiagnosticHttpClient(this.inner, this.diagnostics, {this.anilist = false});
  final http.Client inner;
  final TechnicalDiagnostics diagnostics;
  final bool anilist;

  DiagnosticOperation? _operation(Uri uri) {
    if (anilist) return DiagnosticOperation.match;
    final parts = uri.pathSegments;
    if (parts.isEmpty) return null;
    if (parts.length == 2 && parts.first == 'ai' && parts[1] == 'mood') {
      return DiagnosticOperation.mood;
    }
    if (parts.first == 'import' || parts.first == 'oauth') {
      return DiagnosticOperation.import;
    }
    if (parts.length < 2 || parts.first != 'catalog') return null;
    return switch (parts[1]) {
      'discover' => DiagnosticOperation.discover,
      'search' => DiagnosticOperation.search,
      'title' => DiagnosticOperation.title,
      'match' => DiagnosticOperation.match,
      'aliases' => DiagnosticOperation.aliases,
      _ => null,
    };
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final op = _operation(request.url);
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
