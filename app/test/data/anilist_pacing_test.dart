import 'dart:convert';

import 'package:cue/data/anilist_client.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response ok(Map<String, String> headers) => http.Response(
  jsonEncode({
    'data': {
      'Page': {
        'pageInfo': {'hasNextPage': false},
        'media': <Object>[],
      },
    },
  }),
  200,
  headers: headers,
);

void main() {
  test('follows the rate limit AniList reports by spacing calls', () async {
    var now = DateTime(2026, 11, 1, 12);
    final sleeps = <Duration>[];
    final client = AniListClient(
      client: MockClient((_) async => ok({'x-ratelimit-limit': '30'})),
      sleep: (d) async {
        sleeps.add(d);
        now = now.add(d);
      },
      clock: () => now,
    );
    await client.discover(MediaKind.anime);
    expect(sleeps, isEmpty); // the first call is never delayed
    await client.discover(MediaKind.anime);
    await client.discover(MediaKind.anime);
    // 30 a minute is one call every two seconds.
    expect(sleeps, hasLength(2));
    expect(sleeps.first, greaterThanOrEqualTo(const Duration(seconds: 2)));
    expect(sleeps.first, lessThan(const Duration(milliseconds: 2200)));
  });

  test('a 429 waits as long as Retry-After says, then succeeds', () async {
    final sleeps = <Duration>[];
    var calls = 0;
    final client = AniListClient(
      client: MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('{}', 429, headers: {'retry-after': '7'})
            : ok({});
      }),
      sleep: (d) async => sleeps.add(d),
    );
    final page = await client.discover(MediaKind.anime);
    expect(page.items, isEmpty);
    expect(calls, 2);
    expect(sleeps, [const Duration(seconds: 7)]);
  });

  test('without a readable Retry-After it waits the long default', () async {
    final sleeps = <Duration>[];
    var calls = 0;
    final client = AniListClient(
      client: MockClient(
        (_) async => ++calls == 1 ? http.Response('{}', 429) : ok({}),
      ),
      sleep: (d) async => sleeps.add(d),
    );
    await client.discover(MediaKind.anime);
    expect(sleeps.single, const Duration(seconds: 60));
  });

  test('gives up after two retries with a spent rate_limited error', () async {
    var calls = 0;
    final waits = <Duration>[];
    final client = AniListClient(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 429, headers: {'retry-after': '60'});
      }),
      sleep: (d) async => waits.add(d),
    );
    await expectLater(
      client.discover(MediaKind.anime),
      throwsA(
        isA<CatalogUnavailable>()
            .having((e) => e.code, 'code', 'rate_limited')
            .having((e) => e.retriesSpent, 'retriesSpent', isTrue),
      ),
    );
    expect(calls, 3);
    // Two Retry-After waits at most: one call never blocks for minutes.
    expect(
      waits.where((d) => d == const Duration(seconds: 60)),
      hasLength(AniListClient.rateLimitRetries),
    );
  });

  test(
    'batch lookups send titles as variables and five results each',
    () async {
      late Map<String, dynamic> sent;
      final client = AniListClient(
        client: MockClient((req) async {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return ok({});
        }),
      );
      await client.searchMany(const [
        MatchQuery('Bleach', MediaKind.anime),
        MatchQuery('Murim Login', MediaKind.manhwa),
      ]);
      expect(sent['variables'], {'q0': 'Bleach', 'q1': 'Murim Login'});
      final q = sent['query'] as String;
      expect(q, contains('perPage: 5'));
      // Import labels can misclassify reading origins; discovery stays strict.
      expect(q, isNot(contains('countryOfOrigin:')));
      expect(q, contains('type: ANIME'));
      expect(q, contains('type: MANGA'));
    },
  );

  test('a manga search is not narrowed to Japan', () async {
    late Map<String, dynamic> sent;
    final client = AniListClient(
      client: MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return ok({});
      }),
    );
    await client.search('Solo Leveling', kind: MediaKind.manga);
    expect((sent['variables'] as Map)['country'], isNull);
  });

  test(
    'a Worker batch that fails twice is reported, then the rest still match',
    () async {
      var workerCalls = 0;
      final c = MockClient((req) async {
        if (req.url.host == 'worker.test') {
          workerCalls++;
          return http.Response('{}', 503);
        }
        return ok({});
      });
      final gateway = HybridCatalogGateway(
        HttpCatalogGateway('https://worker.test', client: c),
        AniListClient(client: c),
      );
      final r = await gateway.match(const [
        MatchQuery('A', MediaKind.anime),
        MatchQuery('B', MediaKind.kdrama),
        MatchQuery('C', MediaKind.movie),
      ]);
      expect(workerCalls, 2); // one batch, retried once
      expect(r.failed, {1, 2});
      expect(r.results, hasLength(3));
    },
  );

  test('keeps AniList synonyms so alternate names can match', () {
    final dto = AniListClient.normalize({
      'id': 120385,
      'type': 'MANGA',
      'countryOfOrigin': 'KR',
      'title': {'english': 'Log-in Murim'},
      'synonyms': ['Murim Login', '  ', 42, 'Logando no Murim'],
    });
    expect(dto.names, ['Log-in Murim', 'Murim Login', 'Logando no Murim']);
    expect(dto.kind, MediaKind.manhwa);
  });

  test(
    'looks titles up by AniList id, 50 per call, for comics or anime',
    () async {
      final sent = <Map<String, dynamic>>[];
      final client = AniListClient(
        client: MockClient((req) async {
          sent.add(jsonDecode(req.body) as Map<String, dynamic>);
          return ok({});
        }),
      );
      await client.byIds(List.generate(60, (i) => i + 1), anime: false);
      await client.byIds([1], anime: true);
      expect(await client.byIds(const [], anime: false), isEmpty);
      expect(sent, hasLength(2)); // an empty list makes no request
      expect((sent[0]['variables'] as Map)['ids'], hasLength(50));
      expect((sent[0]['variables'] as Map)['type'], 'MANGA');
      expect((sent[1]['variables'] as Map)['type'], 'ANIME');
      expect(sent[0]['query'], contains('id_in'));
    },
  );

  test(
    'calls made at the same time queue one gap apart instead of bursting',
    () async {
      var now = DateTime(2026, 11, 1, 12);
      final sleeps = <Duration>[];
      final client = AniListClient(
        client: MockClient((_) async => ok({'x-ratelimit-limit': '30'})),
        sleep: (d) async => sleeps.add(d),
        clock: () => now,
      );
      await client.discover(MediaKind.anime); // learns the limit
      now = now.add(const Duration(seconds: 10));
      await Future.wait([
        for (var i = 0; i < 4; i++) client.discover(MediaKind.manhwa),
      ]);
      // The first goes at once; each later one waits one more gap.
      expect(sleeps, hasLength(3));
      expect(sleeps[1] - sleeps[0], greaterThanOrEqualTo(sleeps[0]));
      expect(sleeps[2], greaterThan(const Duration(seconds: 6)));
    },
  );

  test('a 429 slows later calls to the degraded 30 a minute', () async {
    final now = DateTime(2026, 11, 1, 12);
    final sleeps = <Duration>[];
    var calls = 0;
    final client = AniListClient(
      client: MockClient(
        (_) async => ++calls == 1
            ? http.Response('{}', 429, headers: {'retry-after': '3'})
            : ok({}),
      ),
      sleep: (d) async => sleeps.add(d),
      clock: () => now,
    );
    await client.discover(MediaKind.anime);
    expect(sleeps, [const Duration(seconds: 3)]);
    await client.discover(MediaKind.anime);
    expect(sleeps.last, greaterThanOrEqualTo(const Duration(seconds: 2)));
  });

  test(
    'discovery pages through other orders with a stable tie-break',
    () async {
      final sent = <Map<String, dynamic>>[];
      final client = AniListClient(
        client: MockClient((req) async {
          sent.add(jsonDecode(req.body) as Map<String, dynamic>);
          return ok({});
        }),
      );
      await client.discover(MediaKind.anime);
      await client.discover(MediaKind.anime, sort: 'START_DATE_DESC', page: 3);
      await client.discover(MediaKind.anime, sort: 'NOT_A_SORT');
      final vars = [for (final s in sent) s['variables'] as Map];
      expect(vars[0]['sort'], ['POPULARITY_DESC', 'ID']);
      expect(vars[0]['notStatus'], ['CANCELLED']);
      expect(vars[1]['sort'], ['START_DATE_DESC', 'ID']);
      expect(vars[1]['page'], 3);
      // Newest-first skips announced titles nobody can watch yet.
      expect(vars[1]['notStatus'], contains('NOT_YET_RELEASED'));
      expect(vars[2]['sort'], ['POPULARITY_DESC', 'ID']);
      expect(vars[0]['notFormats'], ['MUSIC']);
      expect(AniListClient.sorts, hasLength(5));
    },
  );

  test('recommendations batch four seeds a request, by id only, and drop unsafe or voted-down entries', () async {
    final sent = <Map<String, dynamic>>[];
    Map<String, Object?> media(int id, {String format = 'TV'}) => {
      'id': id,
      'type': 'ANIME',
      'format': format,
      'title': {'romaji': 'Synthetic $id'},
      'isAdult': id == 13,
    };
    final client = AniListClient(
      client: MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        sent.add(body);
        final vars = body['variables'] as Map;
        return http.Response(
          jsonEncode({
            'data': {
              for (var i = 0; i < vars.length; i++)
                'r$i': {
                  'id': vars['i$i'],
                  'recommendations': {
                    'nodes': [
                      {'rating': 40, 'mediaRecommendation': media(11)},
                      {'rating': 5, 'mediaRecommendation': media(12)},
                      {'rating': 9, 'mediaRecommendation': media(13)},
                      {
                        'rating': 9,
                        'mediaRecommendation': media(14, format: 'MUSIC'),
                      },
                      {'rating': -2, 'mediaRecommendation': media(15)},
                      {'rating': 3, 'mediaRecommendation': null},
                    ],
                  },
                },
            },
          }),
          200,
        );
      }),
    );
    final r = await client.recommendations([1, 2, 3, 4, 5]);
    expect(sent, hasLength(2));
    expect(sent[0]['variables'], {'i0': 1, 'i1': 2, 'i2': 3, 'i3': 4});
    expect(sent[1]['variables'], {'i0': 5});
    expect(sent[0]['query'], contains('RATING_DESC'));
    expect(r, hasLength(5));
    expect(r.first.map((d) => d.providerId), ['11', '12']);
  });

  // AniList answers status_not_in: null with a 500, which emptied every
  // anime and comic deck. Only newest-first sends the status filter.
  test('discover never sends a null status filter', () async {
    final sent = <Map<String, dynamic>>[];
    final client = AniListClient(
      client: MockClient((r) async {
        sent.add(
          (jsonDecode(r.body) as Map)['variables'] as Map<String, dynamic>,
        );
        return ok({});
      }),
      sleep: (_) async {},
    );
    for (final sort in AniListClient.sorts) {
      await client.discover(MediaKind.anime, sort: sort);
    }
    for (final v in sent) {
      // Always a list (cancelled series are skipped), never null.
      expect(v['notStatus'], contains('CANCELLED'));
      expect(
        (v['notStatus'] as List).contains('NOT_YET_RELEASED'),
        v['sort'][0] == 'START_DATE_DESC',
      );
    }
  });

  test('no variable is ever sent as null', () async {
    final sent = <Map<String, dynamic>>[];
    final client = AniListClient(
      client: MockClient((r) async {
        sent.add(
          (jsonDecode(r.body) as Map)['variables'] as Map<String, dynamic>,
        );
        return ok({});
      }),
      sleep: (_) async {},
    );
    await client.discover(MediaKind.anime);
    await client.search('Frieren', kind: MediaKind.anime);
    await client.search('Frieren');
    expect(sent, hasLength(3));
    for (final v in sent) {
      expect(v.values, isNot(contains(null)));
    }
    expect(sent.first.containsKey('country'), isFalse);
  });

  // Code Geass carries a minor adult tag; it is not an 18+ title.
  test('only AniList\'s own 18+ flag marks a title adult', () {
    Map<String, Object?> media({required bool isAdult}) => {
      'id': 1575,
      'type': 'ANIME',
      'isAdult': isAdult,
      'title': {'romaji': 'Code Geass'},
      'tags': [
        {'name': 'Masturbation', 'rank': 31, 'isAdult': true},
      ],
    };
    expect(AniListClient.normalize(media(isAdult: false)).json['adult'], false);
    expect(AniListClient.normalize(media(isAdult: true)).json['adult'], true);
  });
}
