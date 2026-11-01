import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cue/diagnostics/technical_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'technical_diagnostics_test.dart' show ConsentMemory;

class _Server {
  DateTime now = DateTime.utc(2026, 11, 1);
  int sequence = 0;
  final requests = <http.Request>[];
  final sessions =
      <String, ({String token, int expiry, List<dynamic> events})>{};
  Future<http.Response> call(http.Request r) async {
    requests.add(r);
    if (r.method == 'POST') {
      final token = base64UrlEncode(List.filled(32, ++sequence))
          .replaceAll('=', '');
      final id = sha256.convert(utf8.encode(token)).toString();
      final events = (jsonDecode(r.body) as Map)['events'] as List;
      final expiry = now.add(const Duration(days: 7)).millisecondsSinceEpoch;
      sessions[id] = (token: token, expiry: expiry, events: events);
      return http.Response(
        jsonEncode({
          'token': token,
          'accepted': events.length,
          'expiresAt': expiry,
        }),
        200,
      );
    }
    final session = sessions[r.url.pathSegments.last];
    if (session == null || now.millisecondsSinceEpoch >= session.expiry) {
      return http.Response('{"error":"not_found"}', 404);
    }
    if (r.headers['Authorization'] != 'Bearer ${session.token}') {
      return http.Response('{"error":"forbidden"}', 403);
    }
    if (r.method == 'GET') {
      return http.Response(jsonEncode({'events': session.events}), 200);
    }
    final events = (jsonDecode(r.body) as Map)['events'] as List;
    session.events.addAll(events);
    return http.Response(
      jsonEncode({'accepted': events.length, 'expiresAt': session.expiry}),
      200,
    );
  }
}

void _event(TechnicalDiagnostics service) => service.finish(
  service.begin(DiagnosticProvider.local, DiagnosticOperation.settings),
  DiagnosticStatus.ok,
  DiagnosticError.none,
);

class _PausedStore extends ConsentMemory {
  Completer<void>? gate;
  final writing = Completer<void>();
  @override
  Future<void> write(String value) async {
    if (gate != null) {
      if (!writing.isCompleted) writing.complete();
      await gate!.future;
    }
    await super.write(value);
  }
}

void main() {
  test(
    'expired restored credential is retired durably before new collection',
    () async {
      final server = _Server();
      final store = ConsentMemory()
        ..value = jsonEncode({
          'version': 2,
          'enabled': true,
          'token': 'A' * 43,
          'expiresAt': server.now.millisecondsSinceEpoch,
        });
      final service = TechnicalDiagnostics(
        'https://synthetic.test',
        store,
        clock: () => server.now,
        clientFactory: () => MockClient(server.call),
      );
      addTearDown(service.dispose);
      await service.load();
      expect(service.enabled, isTrue);
      expect(service.recoveryCode, isNull);
      expect((jsonDecode(store.value!) as Map)['token'], isNull);
      _event(service);
      await service.upload();
      expect(server.requests.single.method, 'POST');
    },
  );

  test(
    'retirement persistence failure never sends another batch under old code',
    () async {
      final server = _Server();
      final store = ConsentMemory();
      final service = TechnicalDiagnostics(
        'https://synthetic.test',
        store,
        clock: () => server.now,
        clientFactory: () => MockClient(server.call),
      );
      addTearDown(service.dispose);
      await service.load();
      await service.setEnabled(true);
      _event(service);
      await service.upload();
      server.now = service.expiresAt!;
      store.fail = true;
      _event(service);
      await service.upload();
      expect(service.enabled, isFalse);
      expect(server.requests, hasLength(1));
      expect(service.message, contains('Collection is off'));
    },
  );

  test('invalid stored version or malformed new credential cannot enable collection', () async {
    for (final record in [
      {'version': 999, 'enabled': true},
      {'version': 2, 'enabled': true, 'token': 'invalid', 'expiresAt': 1},
      {'enabled': true},
    ]) {
      final service = TechnicalDiagnostics(
        'https://synthetic.test',
        ConsentMemory()..value = jsonEncode(record),
      );
      await service.load();
      expect(service.enabled, isFalse);
      expect(service.recoveryCode, isNull);
      expect(service.message, contains('Collection stays off'));
      service.dispose();
    }
  });

  test('server first acceptance starts durable deadline; restart and expiry rotate', () async {
    final server = _Server();
    final store = ConsentMemory();
    TechnicalDiagnostics create() => TechnicalDiagnostics(
      'https://synthetic.test',
      store,
      clock: () => server.now,
      clientFactory: () => MockClient(server.call),
    );
    var service = create();
    await service.load();
    await service.setEnabled(true);
    expect(service.recoveryCode, isNull);
    server.now = server.now.add(const Duration(days: 3));
    _event(service);
    await service.upload();
    final oldCode = service.recoveryCode;
    final expiry = service.expiresAt!;
    expect(expiry, server.now.add(const Duration(days: 7)));
    service.dispose();
    service = create();
    addTearDown(service.dispose);
    await service.load();
    expect(service.recoveryCode, oldCode);
    expect(service.expiresAt, expiry);
    server.now = expiry.subtract(const Duration(milliseconds: 1));
    _event(service);
    await service.upload();
    expect(service.recoveryCode, oldCode);
    server.now = expiry;
    _event(service);
    await service.upload();
    expect(service.recoveryCode, isNot(oldCode));
    expect(
      (jsonDecode(store.value!) as Map)['expiresAt'],
      service.expiresAt!.millisecondsSinceEpoch,
    );
    final oldId = sha256.convert(utf8.encode(oldCode!)).toString();
    expect(server.sessions[oldId]!.events, hasLength(2));
    expect((jsonDecode(await service.export()) as Map)['events'], hasLength(1));
  });

  test('server expiry is authoritative when device clock is behind', () async {
    final server = _Server();
    final deviceNow = server.now;
    final service = TechnicalDiagnostics(
      'https://synthetic.test',
      ConsentMemory(),
      clock: () => deviceNow,
      clientFactory: () => MockClient(server.call),
    );
    addTearDown(service.dispose);
    await service.load();
    await service.setEnabled(true);
    _event(service);
    await service.upload();
    final first = service.recoveryCode;
    server.now = server.now.add(const Duration(days: 7));
    _event(service);
    await service.upload();
    expect(server.requests.map((r) => r.method), ['POST', 'PUT', 'POST']);
    expect(service.recoveryCode, isNot(first));
  });

  test('off/on and explicit new session retire shared codes, not old retained logs', () async {
    final server = _Server();
    final service = TechnicalDiagnostics(
      'https://synthetic.test',
      ConsentMemory(),
      clock: () => server.now,
      clientFactory: () => MockClient(server.call),
    );
    addTearDown(service.dispose);
    await service.load();
    await service.setEnabled(true);
    _event(service);
    await service.upload();
    final first = service.recoveryCode!;
    await service.setEnabled(false);
    expect(service.recoveryCode, first);
    await service.setEnabled(true);
    expect(service.recoveryCode, isNull);
    _event(service);
    await service.upload();
    final second = service.recoveryCode;
    expect(second, isNot(first));
    await service.startNewSession();
    _event(service);
    await service.upload();
    expect(service.recoveryCode, isNot(second));
    final oldId = sha256.convert(utf8.encode(first)).toString();
    expect(server.sessions[oldId]!.events, hasLength(1));
  });

  test(
    'legacy record keeps consent but never reuses client-generated capability',
    () async {
      final store = ConsentMemory()
        ..value = jsonEncode({'enabled': true, 'token': 'A' * 43});
      final server = _Server();
      final service = TechnicalDiagnostics(
        'https://synthetic.test',
        store,
        clientFactory: () => MockClient(server.call),
      );
      addTearDown(service.dispose);
      await service.load();
      expect(service.enabled, isTrue);
      expect(service.recoveryCode, isNull);
      _event(service);
      await service.upload();
      expect(server.requests.single.method, 'POST');
      expect(service.recoveryCode, isNot('A' * 43));
    },
  );

  test('quota and transport errors do not rotate a live capability', () async {
    final server = _Server();
    var fail = false;
    final service = TechnicalDiagnostics(
      'https://synthetic.test',
      ConsentMemory(),
      clientFactory: () => MockClient(
        (r) => fail
            ? Future.value(http.Response('{"error":"unavailable"}', 503))
            : server.call(r),
      ),
    );
    addTearDown(service.dispose);
    await service.load();
    await service.setEnabled(true);
    _event(service);
    await service.upload();
    final code = service.recoveryCode;
    fail = true;
    _event(service);
    await service.upload();
    expect(service.recoveryCode, code);
    expect(service.pendingCount, 1);
    expect(service.message, contains('unavailable'));
  });

  test('creation persistence failure fails closed without exposing unrecorded code', () async {
    final server = _Server();
    final store = ConsentMemory();
    final service = TechnicalDiagnostics(
      'https://synthetic.test',
      store,
      clientFactory: () => MockClient(server.call),
    );
    addTearDown(service.dispose);
    await service.load();
    await service.setEnabled(true);
    store.fail = true;
    _event(service);
    await service.upload();
    expect(service.enabled, isFalse);
    expect(service.pendingCount, 0);
    expect(service.recoveryCode, isNull);
    expect(service.message, contains('Collection is off'));
    expect((jsonDecode(store.value!) as Map)['token'], isNull);
  });

  test('late creation response cannot restore code or pending events after reenable', () async {
    final gate = Completer<http.Response>();
    final server = _Server();
    var first = true;
    final service = TechnicalDiagnostics(
      'https://synthetic.test',
      ConsentMemory(),
      clientFactory: () => MockClient((r) {
        if (first) {
          first = false;
          return gate.future;
        }
        return server.call(r);
      }),
    );
    addTearDown(service.dispose);
    await service.load();
    await service.setEnabled(true);
    _event(service);
    final upload = service.upload();
    await Future<void>.delayed(Duration.zero);
    await service.setEnabled(false);
    await service.setEnabled(true);
    _event(service);
    gate.complete(
      http.Response(
        jsonEncode({
          'token': 'A' * 43,
          'accepted': 1,
          'expiresAt': server.now
              .add(const Duration(days: 7))
              .millisecondsSinceEpoch,
        }),
        200,
      ),
    );
    await upload;
    expect(service.recoveryCode, isNull);
    expect(service.pendingCount, 1);
    await service.upload();
    expect(service.recoveryCode, isNot('A' * 43));
  });

  test(
    'disable wins against a queued session-credential persistence write',
    () async {
      final store = _PausedStore();
      final server = _Server();
      final service = TechnicalDiagnostics(
        'https://synthetic.test',
        store,
        clientFactory: () => MockClient(server.call),
      );
      addTearDown(service.dispose);
      await service.load();
      await service.setEnabled(true);
      store.gate = Completer<void>();
      _event(service);
      final upload = service.upload();
      await store.writing.future;
      final disable = service.setEnabled(false);
      store.gate!.complete();
      await upload;
      await disable;
      expect(service.enabled, isFalse);
      expect(service.recoveryCode, isNull);
      expect((jsonDecode(store.value!) as Map)['enabled'], isFalse);
      expect((jsonDecode(store.value!) as Map)['token'], isNull);
    },
  );
}
