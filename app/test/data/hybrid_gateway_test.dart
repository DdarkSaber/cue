import 'dart:convert';

import 'package:cue/data/anilist_client.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fakes.dart';

void main() {
  late List<http.Request> sent;

  http.Client client() => MockClient((req) async {
    sent.add(req);
    if (req.url.host == 'graphql.anilist.co') {
      return http.Response(
        jsonEncode({
          'data': {
            'Page': {
              'pageInfo': {'hasNextPage': false},
              'media': [
                {
                  'id': 7,
                  'type': 'MANGA',
                  'countryOfOrigin': 'KR',
                  'status': 'RELEASING',
                  'title': {'english': 'Synthetic'},
                  'genres': ['Action'],
                  'tags': [],
                },
              ],
            },
          },
        }),
        200,
      );
    }
    return http.Response(jsonEncode({'items': [], 'hasNext': false}), 200);
  });

  HybridCatalogGateway gateway({bool web = false}) {
    final c = client();
    return HybridCatalogGateway(
      HttpCatalogGateway('https://worker.test', client: c, proxyImages: web),
      AniListClient(client: c),
      web: web,
    );
  }

  setUp(() => sent = []);

  test('anime and reading kinds go to AniList directly', () async {
    final page = await gateway().discover(MediaKind.manhwa, mood: 'hype');
    expect(sent.single.url.host, 'graphql.anilist.co');
    final vars = jsonDecode(sent.single.body)['variables'] as Map;
    expect(vars, containsPair('country', 'KR'));
    expect(vars['genres'], ['Action', 'Sports']);
    expect(page.items.single.kind, MediaKind.manhwa);
    expect(page.items.single.json['status'], 'ongoing');
  });

  test('dramas, series and movies go to the Worker', () async {
    await gateway().discover(MediaKind.kdrama);
    expect(sent.single.url.host, 'worker.test');
    expect(sent.single.url.path, '/catalog/discover');
  });

  test('batch match splits AniList and Worker titles', () async {
    await gateway().match(const [
      MatchQuery('A', MediaKind.anime),
      MatchQuery('B', MediaKind.kdrama),
    ]);
    final hosts = sent.map((r) => r.url.host).toList();
    expect(hosts, containsAll(['graphql.anilist.co', 'worker.test']));
    final ani = sent.firstWhere((r) => r.url.host == 'graphql.anilist.co');
    expect(jsonDecode(ani.body)['variables'], {'q0': 'A'});
  });

  test('web loads AniList posters directly and proxies the rest', () {
    final g = gateway(web: true);
    expect(
      g.imageUrl('https://s4.anilist.co/x.jpg'),
      'https://s4.anilist.co/x.jpg',
    );
    expect(
      g.imageUrl('https://image.tmdb.org/t/p/w500/x.jpg'),
      startsWith('https://worker.test/catalog/image?u='),
    );
    expect(
      gateway().imageUrl('https://image.tmdb.org/x.jpg'),
      'https://image.tmdb.org/x.jpg',
    );
  });

  test('AniList username lists need no Worker', () async {
    await gateway().listByUser('anilist', 'someone');
    expect(sent.every((r) => r.url.host == 'graphql.anilist.co'), isTrue);
  });

  test(
    'manual search keeps all anime and comic results, not just six',
    () async {
      final types = <String>[];
      final c = MockClient((req) async {
        if (req.url.host == 'graphql.anilist.co') {
          final vars = jsonDecode(req.body)['variables'] as Map;
          types.add(vars['type'] as String);
          return http.Response(
            jsonEncode({
              'data': {
                'Page': {
                  'media': [
                    for (var i = 0; i < 10; i++)
                      {
                        'id': (vars['type'] == 'ANIME' ? 100 : 200) + i,
                        'type': vars['type'],
                        'countryOfOrigin': 'KR',
                        'title': {'english': 'Invented search result $i'},
                      },
                  ],
                },
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'items': [],
            'results': [[]],
          }),
          200,
        );
      });
      final g = HybridCatalogGateway(
        HttpCatalogGateway('https://worker.test', client: c),
        AniListClient(client: c),
      );
      final results = await g.search('Invented');
      expect(types, containsAll(['ANIME', 'MANGA']));
      expect(results, hasLength(20));
      expect(
        results.map((r) => r.titleId),
        containsAll(['anilist:109', 'anilist:209']),
      );
    },
  );

  test(
    'manual comic search includes alias links and direct fallback cards',
    () async {
      final c = MockClient((req) async {
        if (req.url.host == 'graphql.anilist.co') {
          final vars = jsonDecode(req.body)['variables'] as Map;
          return http.Response(
            jsonEncode({
              'data': {
                'Page': {
                  'media': [
                    if (vars.containsKey('ids'))
                      {
                        'id': 42,
                        'type': 'MANGA',
                        'countryOfOrigin': 'KR',
                        'title': {'english': 'Invented official comic'},
                      },
                  ],
                },
              },
            }),
            200,
          );
        }
        if (req.url.path == '/catalog/aliases') {
          final source = jsonDecode(req.body)['source'];
          return http.Response(
            jsonEncode({
              'results': [
                [
                  if (source == 'mangadex')
                    {
                      'names': ['Invented fan alias'],
                      'al': 42,
                    }
                  else
                    {
                      'names': ['Invented fan alias'],
                      'item': item(
                        77,
                        provider: 'mangaupdates',
                        kind: 'manhua',
                      ),
                    },
                ],
              ],
            }),
            200,
          );
        }
        return http.Response('{"items":[]}', 200);
      });
      final g = HybridCatalogGateway(
        HttpCatalogGateway('https://worker.test', client: c),
        AniListClient(client: c),
      );
      final results = await g.search(
        'Invented fan alias',
        kind: MediaKind.manhwa,
      );
      expect(
        results.map((r) => r.titleId),
        containsAll(['anilist:42', 'mangaupdates:77']),
      );
    },
  );

  test(
    'partial and total provider failures are not reported as no matches',
    () async {
      var failAnime = true;
      final c = MockClient((req) async {
        if (req.url.host == 'graphql.anilist.co') {
          if (failAnime) return http.Response('{}', 503);
          return http.Response('{"data":{"Page":{"media":[]}}}', 200);
        }
        if (req.url.path == '/catalog/search') {
          return http.Response(
            jsonEncode({
              'items': [item(8, kind: 'movie')],
            }),
            200,
          );
        }
        return http.Response('{"results":[[]]}', 200);
      });
      final g = HybridCatalogGateway(
        HttpCatalogGateway('https://worker.test', client: c),
        AniListClient(client: c),
      );
      await expectLater(
        g.search('Invented'),
        throwsA(
          isA<CatalogSearchIncomplete>()
              .having((e) => e.code, 'code', 'upstream_error')
              .having(
                (e) => e.items.single.titleId,
                'screen result',
                'anilist:8',
              ),
        ),
      );
      await expectLater(
        g.search('Invented', kind: MediaKind.anime),
        throwsA(
          isA<CatalogSearchIncomplete>().having(
            (e) => e.items,
            'items',
            isEmpty,
          ),
        ),
      );
      failAnime = false;
      expect(await g.search('Invented', kind: MediaKind.anime), isEmpty);
    },
  );

  test('HTTP 200 GraphQL errors remain visible search failures', () async {
    final c = MockClient(
      (req) async => http.Response(
        '{"errors":[{"message":"Synthetic provider error"}]}',
        200,
      ),
    );
    await expectLater(
      AniListClient(client: c).search('Invented'),
      throwsA(
        isA<CatalogUnavailable>().having(
          (e) => e.code,
          'code',
          'upstream_error',
        ),
      ),
    );
  });

  test('unknown import kinds search AniList, and its failure does not block screen matches', () async {
    final c = MockClient((req) async {
      if (req.url.host == 'graphql.anilist.co') return http.Response('{}', 503);
      return http.Response(
        jsonEncode({
          'results': [
            [item(88, provider: 'cinemeta', kind: 'movie')],
          ],
          'mal': [],
        }),
        200,
      );
    });
    final g = HybridCatalogGateway(
      HttpCatalogGateway('https://worker.test', client: c),
      AniListClient(client: c),
    );
    final result = await g.match(const [
      MatchQuery('Invented', MediaKind.unknown),
    ]);
    expect(result.failed, {0});
    expect(result.results.single.single.titleId, 'cinemeta:88');
  });

  test(
    'a failing AniList falls back to MyAnimeList, offline does not',
    () async {
      final asked = <Uri>[];
      var anilistDown = true;
      final g = HybridCatalogGateway(
        HttpCatalogGateway(
          'https://worker.example',
          client: MockClient((req) async {
            asked.add(req.url);
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'provider': 'mal',
                    'providerId': '9',
                    'providerKind': 'manga',
                    'idMal': 9,
                    'kind': 'manhwa',
                    'titleRomaji': 'Synthetic Backup',
                  },
                ],
                'hasNext': true,
              }),
              200,
            );
          }),
        ),
        AniListClient(
          client: MockClient(
            (_) async => anilistDown
                ? http.Response('{}', 500)
                : throw const SocketExceptionLike(),
          ),
          sleep: (_) async {},
        ),
      );
      final page = await g.discover(MediaKind.manhwa, page: 3);
      expect(page.items.single.json['provider'], 'mal');
      expect(page.hasNext, isTrue);
      expect(asked.single.queryParameters, {
        'kind': 'manhwa',
        'page': '3',
        'source': 'mal',
      });
      anilistDown = false;
      asked.clear();
      await expectLater(
        g.discover(MediaKind.manhwa),
        throwsA(
          isA<CatalogUnavailable>().having((e) => e.code, 'code', 'offline'),
        ),
      );
      expect(asked, isEmpty);
    },
  );
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
