import 'dart:convert';

import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/request_pacer.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('RequestPacer', () {
    late DateTime now;
    late List<Duration> sleeps;
    RequestPacer pacer(int perMinute) => RequestPacer(
      maxPerMinute: perMinute,
      sleep: (d) async {
        sleeps.add(d);
        now = now.add(d);
      },
      clock: () => now,
    );
    setUp(() {
      now = DateTime(2026, 11, 5, 12);
      sleeps = [];
    });

    test('lets a minute\'s worth through, then waits for the window', () async {
      final p = pacer(3);
      for (var i = 0; i < 3; i++) {
        await p.run(() async => i);
        now = now.add(const Duration(seconds: 1));
      }
      expect(sleeps, isEmpty);
      await p.run(() async => 0);
      // The first call was 3 s ago: the window frees 57 s later.
      expect(sleeps, [const Duration(seconds: 57)]);
    });

    test('a 429 waits as long as Retry-After says, then tries again', () async {
      final p = pacer(10);
      var calls = 0;
      final r = await p.run(() async {
        if (calls++ == 0) {
          throw const CatalogUnavailable(
            'rate_limited',
            retryAfter: Duration(seconds: 7),
          );
        }
        return 'ok';
      });
      expect(r, 'ok');
      expect(sleeps, [const Duration(seconds: 7)]);
    });

    test(
      'without Retry-After a 429 waits a minute; long waits are capped',
      () async {
        final p = pacer(10);
        var calls = 0;
        await p.run(() async {
          calls++;
          if (calls == 1) throw const CatalogUnavailable('http_429');
          if (calls == 2) {
            throw const CatalogUnavailable(
              'rate_limited',
              retryAfter: Duration(hours: 1),
            );
          }
          return 0;
        });
        expect(sleeps, [RequestPacer.defaultWait, RequestPacer.maxWait]);
      },
    );

    test(
      'gives up after two retries; other failures are not retried',
      () async {
        final p = pacer(10);
        var calls = 0;
        await expectLater(
          p.run<int>(() async {
            calls++;
            throw const CatalogUnavailable('rate_limited');
          }),
          throwsA(isA<CatalogUnavailable>()),
        );
        expect(calls, 1 + RequestPacer.maxRetries);
        calls = 0;
        await expectLater(
          p.run<int>(() async {
            calls++;
            throw const CatalogUnavailable('offline');
          }),
          throwsA(isA<CatalogUnavailable>()),
        );
        expect(calls, 1);
      },
    );
  });

  group('Worker lookups through HttpCatalogGateway', () {
    test('MAL search sends each name with its list and reads cards', () async {
      late Map<String, dynamic> sent;
      final c = MockClient((req) async {
        expect(req.url.path, '/catalog/mal-search');
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'results': [
              [
                {
                  'provider': 'mal',
                  'providerId': '5',
                  'providerKind': 'anime',
                  'idMal': 5,
                  'kind': 'anime',
                  'titleEn': 'Synthetic',
                  'synonyms': ['Other Name'],
                },
              ],
              <Object>[],
            ],
          }),
          200,
        );
      });
      final g = HttpCatalogGateway('https://worker.test', client: c);
      final r = await g.malSearch(const [
        MalQuery('One', anime: true),
        MalQuery('Two', anime: false),
      ]);
      expect(sent['items'], [
        {'q': 'One', 'kind': 'anime'},
        {'q': 'Two', 'kind': 'manga'},
      ]);
      expect(r, hasLength(2));
      expect(r.first.single.titleId, 'mal:anime:5');
      expect(r.first.single.names, contains('Other Name'));
      expect(r.last, isEmpty);
    });

    test(
      'canonical names carry the kind and read titles and redirects',
      () async {
        late Map<String, dynamic> sent;
        final c = MockClient((req) async {
          expect(req.url.path, '/catalog/names');
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'results': [
                [
                  {
                    'title': 'Canonical',
                    'names': ['Alias'],
                  },
                ],
              ],
            }),
            200,
          );
        });
        final g = HttpCatalogGateway('https://worker.test', client: c);
        final r = await g.canonicalNames(const [
          'Messy',
        ], kind: MediaKind.manhwa);
        expect(sent, {
          'items': [
            {'q': 'Messy'},
          ],
          'kind': 'manhwa',
        });
        expect(r.single.single.title, 'Canonical');
        expect(r.single.single.names, ['Alias']);
      },
    );

    test(
      'a refused match batch waits out Retry-After and is sent again',
      () async {
        final sleeps = <Duration>[];
        var calls = 0;
        final c = MockClient((req) async {
          calls++;
          if (calls == 1) {
            return http.Response(
              jsonEncode({'error': 'rate_limited'}),
              429,
              headers: {'retry-after': '12'},
            );
          }
          return http.Response(
            jsonEncode({
              'results': [<Object>[]],
              'mal': <Object>[],
            }),
            200,
          );
        });
        final g = HttpCatalogGateway(
          'https://worker.test',
          client: c,
          heavyPacer: RequestPacer(
            maxPerMinute: HttpCatalogGateway.heavyPerMinute,
            sleep: (d) async => sleeps.add(d),
          ),
        );
        final r = await g.match(const [MatchQuery('A', MediaKind.kdrama)]);
        expect(r.results, hasLength(1));
        expect(calls, 2);
        expect(sleeps, [const Duration(seconds: 12)]);
      },
    );

    test(
      'match and alias calls share one budget under the Worker limit',
      () async {
        var now = DateTime(2026, 11, 5, 12);
        final sleeps = <Duration>[];
        final c = MockClient(
          (req) async => http.Response(
            jsonEncode({'results': <Object>[], 'mal': <Object>[]}),
            200,
          ),
        );
        final g = HttpCatalogGateway(
          'https://worker.test',
          client: c,
          heavyPacer: RequestPacer(
            maxPerMinute: HttpCatalogGateway.heavyPerMinute,
            sleep: (d) async {
              sleeps.add(d);
              now = now.add(d);
            },
            clock: () => now,
          ),
        );
        for (var i = 0; i < HttpCatalogGateway.heavyPerMinute; i++) {
          i.isEven
              ? await g.match(const [MatchQuery('A', MediaKind.kdrama)])
              : await g.aliases(const ['A']);
        }
        expect(sleeps, isEmpty);
        await g.aliases(const ['A']);
        expect(sleeps, hasLength(1));
        expect(HttpCatalogGateway.heavyPerMinute, lessThan(20));
        expect(HttpCatalogGateway.lookupPerMinute, lessThan(30));
      },
    );
  });
}
