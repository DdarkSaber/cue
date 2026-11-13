import 'dart:convert';

import 'package:cue/data/anilist_client.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Map<String, dynamic> item(String id) => {
    'provider': 'tmdb',
    'providerId': id,
    'kind': 'kdrama',
    'title': 'T$id',
  };

  HttpCatalogGateway worker(Map<String, dynamic> body) => HttpCatalogGateway(
    'https://worker.test',
    client: MockClient((_) async => http.Response(jsonEncode(body), 200)),
  );

  const queries = [
    MatchQuery('A', MediaKind.kdrama),
    MatchQuery('B', MediaKind.kdrama),
  ];

  test('the failed list from the Worker is read', () async {
    final r = await worker({
      'results': [
        [item('1')],
        [],
      ],
      'mal': [],
      'failed': [1],
    }).match(queries);
    expect(r.results, hasLength(2));
    expect(r.results.first.single.providerId, '1');
    expect(r.failed, {1});
  });

  test('an older Worker without a failed list still matches', () async {
    final r = await worker({
      'results': [
        [item('1')],
        [],
      ],
      'mal': [],
    }).match(queries);
    expect(r.results, hasLength(2));
    expect(r.failed, isEmpty);
  });

  test('the hybrid gateway passes failed positions through', () async {
    final w = worker({
      'results': [
        [item('1')],
        [],
      ],
      'mal': [],
      'failed': [1],
    });
    final g = HybridCatalogGateway(
      w,
      AniListClient(client: MockClient((_) async => http.Response('{}', 500))),
    );
    final r = await g.match(queries);
    expect(r.results[0].single.providerId, '1');
    expect(r.results[1], isEmpty);
    expect(r.failed, {1});
  });
}
