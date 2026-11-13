import 'dart:async';
import 'dart:convert';

import 'package:cue/data/anilist_client.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/diagnostics/technical_diagnostics.dart';
import 'package:cue/domain/models/title.dart';
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

http.Response _ack(http.Request request) => http.Response(
  jsonEncode({
    'accepted': 1,
    'expiresAt': DateTime.utc(2030).millisecondsSinceEpoch,
    if (request.method == 'POST') 'token': 'A' * 43,
  }),
  200,
);

void main() {
  test('default off, no retrospective requests, disable drops pending/inflight result', () async {
    final store = ConsentMemory();
    final requests = <http.Request>[];
    final service = TechnicalDiagnostics(
      'https://synthetic.test',
      store,
      clientFactory: () => MockClient((r) async {
        requests.add(r);
        return _ack(r);
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
        return _ack(r);
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
    expect(uploads.first.headers['Authorization'], isNull);
    expect(uploads.first.url.path, '/diagnostics');
    expect(uploads.last.url.path, '/diagnostics/${service.sessionId}');
    expect(
      uploads.last.headers['Authorization'],
      'Bearer ${service.recoveryCode}',
    );
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
          (r) async => r.method == 'POST'
              ? _ack(r)
              : http.Response('{"events":[{"title":"PRIVATE"}]}', 200),
        ),
      );
      addTearDown(service.dispose);
      await service.load();
      await service.setEnabled(true);
      service.finish(
        service.begin(DiagnosticProvider.local, DiagnosticOperation.settings),
        DiagnosticStatus.ok,
        DiagnosticError.none,
      );
      await service.upload();
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

  group('operation labels and body failures', () {
    late List<http.Request> uploads;
    late TechnicalDiagnostics service;

    setUp(() async {
      uploads = [];
      service = TechnicalDiagnostics(
        'https://synthetic.test',
        ConsentMemory(),
        clientFactory: () => MockClient((r) async {
          uploads.add(r);
          return _ack(r);
        }),
      );
      await service.load();
      await service.setEnabled(true);
    });
    tearDown(() => service.dispose());

    Future<List<Map<String, dynamic>>> events() async {
      await service.upload();
      return [
        for (final u in uploads)
          for (final e in (jsonDecode(u.body) as Map)['events'] as List)
            Map<String, dynamic>.from(e as Map),
      ];
    }

    test(
      'Worker routes are labelled; sync, uploads and images are not',
      () async {
        final wrapped = DiagnosticHttpClient(
          MockClient((r) async => http.Response('{}', 200)),
          service,
        );
        addTearDown(wrapped.close);
        for (final path in [
          '/catalog/mal-search',
          '/catalog/names',
          '/catalog/recommendations/tmdb/1',
          '/ai/recommend',
          '/sync/abc',
          '/diagnostics',
          '/catalog/image',
        ]) {
          await wrapped.post(Uri.parse('https://synthetic.test$path'));
        }
        final ops = [for (final e in await events()) e['operation']];
        expect(ops, ['aliases', 'aliases', 'discover', 'mood']);
      },
    );

    test('AniList requests carry their own operation, and AniList never sees the tag', () async {
      final seen = <http.BaseRequest>[];
      final anilist = AniListClient(
        client: DiagnosticHttpClient(
          MockClient((r) async {
            seen.add(r);
            return http.Response(
              jsonEncode({
                'data': {
                  'Page': {
                    'media': [],
                    'pageInfo': {'hasNextPage': false},
                  },
                  'Viewer': {'name': 'x'},
                },
              }),
              200,
            );
          }),
          service,
          anilist: true,
        ),
        tagOperations: true,
        sleep: (_) async {},
      );
      await anilist.discover(MediaKind.anime);
      await anilist.search('PRIVATE_TITLE');
      await anilist.searchMany(const [MatchQuery('PRIVATE_TITLE')]);
      await anilist.byIds(const [1], anime: true);
      await anilist.viewerName('PRIVATE_TOKEN');
      expect(
        seen.every(
          (r) => !r.headers.keys.any(
            (k) => k.toLowerCase() == diagnosticOperationHeader.toLowerCase(),
          ),
        ),
        isTrue,
      );
      final ops = [for (final e in await events()) e['operation']];
      expect(ops, ['discover', 'search', 'match', 'title', 'import']);
      expect(uploads.single.body, isNot(contains('PRIVATE')));
    });

    test(
      'a 200 with GraphQL errors or no JSON is reported as invalid',
      () async {
        var body = jsonEncode({
          'errors': [
            {'message': 'PRIVATE_ERROR'},
          ],
        });
        final anilist = AniListClient(
          client: DiagnosticHttpClient(
            MockClient((r) async => http.Response(body, 200)),
            service,
            anilist: true,
          ),
          tagOperations: true,
          sleep: (_) async {},
          onInvalid: (op) =>
              service.reportInvalid(DiagnosticProvider.anilist, op),
        );
        await expectLater(
          anilist.title('1'),
          throwsA(isA<CatalogUnavailable>()),
        );
        body = '<html>PRIVATE_PAGE</html>';
        await expectLater(
          anilist.discover(MediaKind.anime),
          throwsA(isA<CatalogUnavailable>()),
        );
        final all = await events();
        final invalid = [
          for (final e in all)
            if (e['status'] == 'failed') e,
        ];
        expect(
          [for (final e in invalid) e['operation']],
          ['title', 'discover'],
        );
        expect(
          invalid.every((e) => e['errorCode'] == 'invalid_response'),
          isTrue,
        );
        expect(invalid.every((e) => e['durationMs'] == 0), isTrue);
        expect(invalid.every((e) => e['provider'] == 'anilist'), isTrue);
        expect(uploads.single.body, isNot(contains('PRIVATE')));
      },
    );

    test('an untagged AniList client sends no tag at all', () async {
      final seen = <http.BaseRequest>[];
      final anilist = AniListClient(
        client: MockClient((r) async {
          seen.add(r);
          return http.Response('{"data":{}}', 200);
        }),
        sleep: (_) async {},
      );
      await anilist.title('1');
      expect(
        seen.single.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains(diagnosticOperationHeader.toLowerCase())),
      );
    });
  });
}
