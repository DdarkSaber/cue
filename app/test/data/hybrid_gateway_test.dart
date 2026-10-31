import 'dart:convert';

import 'package:cue/data/anilist_client.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
}
