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

  test('gives up after three retries with a rate_limited error', () async {
    var calls = 0;
    final client = AniListClient(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 429, headers: {'retry-after': '1'});
      }),
      sleep: (_) async {},
    );
    await expectLater(
      client.discover(MediaKind.anime),
      throwsA(
        isA<CatalogUnavailable>().having((e) => e.code, 'code', 'rate_limited'),
      ),
    );
    expect(calls, 4);
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
      // Only manhwa and manhua are narrowed by country; manga comes from anywhere.
      expect(q, contains('countryOfOrigin: KR'));
      expect(q, isNot(contains('countryOfOrigin: JP')));
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
}
