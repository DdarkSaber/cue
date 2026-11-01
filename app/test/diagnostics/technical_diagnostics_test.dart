import 'dart:async';
import 'dart:convert';

import 'package:cue/diagnostics/technical_diagnostics.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

class ConsentMemory implements DiagnosticConsentStore {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    if (fail) throw StateError('Synthetic private secret must not be logged');
    value = v;
  }
}

void main() {
  test('default off, no retrospective requests, disable drops pending/inflight result', () async {
    final store = ConsentMemory();
    final requests = <http.Request>[];
    final service = TechnicalDiagnostics(
      'https://synthetic.test',
      store,
      clientFactory: () => MockClient((r) async {
        requests.add(r);
        return http.Response('{"accepted":1}', 200);
      }),
    );
    addTearDown(service.dispose);
    await service.load();
    final before = service.begin(
      DiagnosticProvider.cue,
      DiagnosticOperation.search,
    );
    expect(before, isNull);
    await service.setEnabled(true);
    service.finish(before, DiagnosticStatus.ok, DiagnosticError.none);
    expect(service.pendingCount, 0);
    final after = service.begin(
      DiagnosticProvider.cue,
      DiagnosticOperation.match,
    );
    await service.setEnabled(false);
    service.finish(after, DiagnosticStatus.ok, DiagnosticError.none);
    await service.upload();
    expect(requests, isEmpty);
    expect(service.pendingCount, 0);
    expect(jsonDecode(store.value!)['enabled'], isFalse);
  });

  test('technical HTTP payload is allowlisted despite secret URL, body and headers', () async {
    final uploads = <http.Request>[];
    final store = ConsentMemory();
    final service = TechnicalDiagnostics(
      'https://synthetic.test',
      store,
      clientFactory: () => MockClient((r) async {
        uploads.add(r);
        return http.Response('{"accepted":1}', 200);
      }),
    );
    addTearDown(service.dispose);
    await service.load();
    await service.setEnabled(true);
    final wrapped = DiagnosticHttpClient(
      MockClient((r) async => http.Response('private title', 503)),
      service,
    );
    addTearDown(wrapped.close);
    await wrapped.post(
      Uri.parse('https://synthetic.test/catalog/match?q=PRIVATE_SEARCH'),
      headers: {'Authorization': 'Bearer PRIVATE_KEY'},
      body: 'PRIVATE_WORKBOOK',
    );
    await service.upload();
    final uploaded = jsonDecode(uploads.single.body) as Map;
    final event = (uploaded['events'] as List).single as Map;
    expect(event.keys.toSet(), {
      'requestId',
      'appVersion',
      'provider',
      'operation',
      'durationMs',
      'status',
      'errorCode',
    });
    expect(event['operation'], 'match');
    expect(event['errorCode'], 'http_5xx');
    await wrapped.post(
      Uri.parse('https://synthetic.test/ai/mood'),
      body: 'PRIVATE_MOOD_PHRASE',
      headers: {'Authorization': 'PRIVATE_KEY'},
    );
    await service.upload();
    final moodEvent =
        ((jsonDecode(uploads.last.body) as Map)['events'] as List).single
            as Map;
    expect(moodEvent['operation'], 'mood');
    expect(moodEvent['provider'], 'cue');
    expect(uploads.last.body, isNot(contains('PRIVATE_MOOD_PHRASE')));
    expect(uploads.last.body, isNot(contains('PRIVATE_KEY')));
    expect(uploads.last.body, isNot(contains('private title')));
    expect(uploads.first.body, isNot(contains('PRIVATE')));
    expect(uploads.first.body, isNot(contains('private title')));
    expect(uploads.first.body, isNot(contains(service.recoveryCode!)));
    expect(
      uploads.first.headers['Authorization'],
      'Bearer ${service.recoveryCode}',
    );
    expect(uploads.first.url.path, '/diagnostics/${service.sessionId}');
    expect(service.pendingCount, 0);
  });

  test(
    'quota/network failures explicit, bounded memory and no retry loop',
    () async {
      var calls = 0;
      final service = TechnicalDiagnostics(
        'https://synthetic.test',
        ConsentMemory(),
        clientFactory: () => MockClient((r) async {
          calls++;
          return http.Response('{"error":"quota"}', 429);
        }),
      );
      addTearDown(service.dispose);
      await service.load();
      await service.setEnabled(true);
      for (var i = 0; i < 30; i++) {
        service.finish(
          service.begin(DiagnosticProvider.local, DiagnosticOperation.settings),
          DiagnosticStatus.failed,
          DiagnosticError.storageFailed,
        );
      }
      expect(service.pendingCount, 20);
      expect(service.message, contains('limit'));
      await service.upload();
      expect(service.message, contains('quota'));
      expect(service.pendingCount, 20);
      expect(calls, 1);
      await service.setEnabled(false);
      expect(service.pendingCount, 0);
    },
  );

  test('consent persistence failure stays off and does not collect', () async {
    final store = ConsentMemory()..fail = true;
    final service = TechnicalDiagnostics('https://synthetic.test', store);
    addTearDown(service.dispose);
    await service.load();
    await expectLater(service.setEnabled(true), throwsStateError);
    expect(service.enabled, isFalse);
    expect(service.message, isNot(contains('private secret')));
    expect(
      service.begin(DiagnosticProvider.cue, DiagnosticOperation.search),
      isNull,
    );
  });

  test(
    '200 without valid acknowledgement cannot claim upload success',
    () async {
      final service = TechnicalDiagnostics(
        'https://synthetic.test',
        ConsentMemory(),
        clientFactory: () =>
            MockClient((r) async => http.Response('{"ok":true}', 200)),
      );
      addTearDown(service.dispose);
      await service.load();
      await service.setEnabled(true);
      service.finish(
        service.begin(DiagnosticProvider.cue, DiagnosticOperation.title),
        DiagnosticStatus.ok,
        DiagnosticError.none,
      );
      await service.upload();
      expect(service.pendingCount, 1);
      expect(service.message, contains('failed'));
    },
  );

  test(
    'export rejects extra personal fields and does not export capability',
    () async {
      final service = TechnicalDiagnostics(
        'https://synthetic.test',
        ConsentMemory(),
        clientFactory: () => MockClient(
          (r) async => http.Response('{"events":[{"title":"PRIVATE"}]}', 200),
        ),
      );
      addTearDown(service.dispose);
      await service.load();
      await service.setEnabled(true);
      await expectLater(service.export(), throwsFormatException);
    },
  );

  test('turning off while uploading cancels local acknowledgement and pending data', () async {
    final gate = Completer<http.Response>();
    final service = TechnicalDiagnostics(
      'https://synthetic.test',
      ConsentMemory(),
      clientFactory: () => MockClient((r) => gate.future),
    );
    addTearDown(service.dispose);
    await service.load();
    await service.setEnabled(true);
    service.finish(
      service.begin(DiagnosticProvider.cue, DiagnosticOperation.title),
      DiagnosticStatus.ok,
      DiagnosticError.none,
    );
    final upload = service.upload();
    await Future<void>.delayed(Duration.zero);
    await service.setEnabled(false);
    gate.complete(http.Response('{"accepted":1}', 200));
    await upload;
    expect(service.enabled, isFalse);
    expect(service.pendingCount, 0);
    expect(service.message, contains('off'));
  });
}
