import 'dart:convert';

import 'package:cue/data/mangaupdates_client.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const comic = Title(
    id: 'mu-test-1',
    kind: MediaKind.manhwa,
    titleEn: 'Invented Reader',
    titleRomaji: 'Invented Dokja',
    status: 'ongoing',
    year: 2020,
  );

  MockClient api({required int latest}) => MockClient((req) async {
    if (req.url.path.endsWith('/series/search')) {
      return http.Response(
        jsonEncode({
          'results': [
            {
              'record': {
                'series_id': 1,
                'title': 'Invented Reader (Novel)',
                'type': 'Novel',
                'year': '2020',
              },
            },
            {
              'record': {
                'series_id': 2,
                'title': 'Invented Reader',
                'type': 'Manhwa',
                'year': '2020',
              },
            },
          ],
        }),
        200,
      );
    }
    expect(req.url.path, endsWith('/series/2'));
    return http.Response(jsonEncode({'latest_chapter': latest}), 200);
  });

  test(
    'takes the latest chapter of the same-named series of that type',
    () async {
      final n = await MangaUpdatesClient(
        client: api(latest: 308),
        enabled: true,
      ).latestChapter(comic);
      expect(n, 308);
    },
  );

  test('does nothing on the web or for anime', () async {
    final off = MangaUpdatesClient(client: api(latest: 1), enabled: false);
    expect(await off.latestChapter(comic), isNull);
    const anime = Title(id: 'mu-test-2', kind: MediaKind.anime, titleEn: 'X');
    expect(
      await MangaUpdatesClient(
        client: api(latest: 1),
        enabled: true,
      ).latestChapter(anime),
      isNull,
    );
  });

  test('a failed lookup is not fatal', () async {
    final n =
        await MangaUpdatesClient(
          client: MockClient((_) async => http.Response('nope', 403)),
          enabled: true,
        ).latestChapter(
          const Title(id: 'mu-test-3', kind: MediaKind.manga, titleEn: 'Y'),
        );
    expect(n, isNull);
  });
}
