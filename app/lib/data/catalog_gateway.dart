import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models/title.dart';
import 'anilist_client.dart';

/// A catalog title as the Worker sends it.
class CatalogItemDto {
  const CatalogItemDto(this.json);
  final Map<String, dynamic> json;

  String get provider => json['provider'] as String;
  String get providerId => json['providerId'] as String;
  String? get providerKind => json['providerKind'] as String?;
  int? get idMal => (json['idMal'] as num?)?.toInt();

  /// Stable local id built from the provider identity.
  String get titleId => [
    provider,
    if (providerKind != null && providerKind!.isNotEmpty) providerKind,
    providerId,
  ].join(':');

  MediaKind get kind => MediaKind.parse(json['kind'] as String?);

  /// Every name the provider gives: titles plus alternate names.
  List<String> get names => [
    for (final k in ['titleEn', 'titleRomaji', 'titleNative'])
      if (json[k] is String && (json[k] as String).trim().isNotEmpty)
        json[k] as String,
    for (final s in (json['synonyms'] as List?) ?? const [])
      if (s is String) s,
  ];
}

/// Another database's view of a comic: all its names and its links to
/// AniList and MyAnimeList. Used only to turn a typed name into an id.
class AliasCandidateDto {
  const AliasCandidateDto({
    required this.names,
    this.al,
    this.mal,
    this.lang,
    this.item,
  });

  final List<String> names;
  final int? al;
  final int? mal;

  /// Original language: ko, zh or ja.
  final String? lang;

  /// A ready card, when the source (MangaUpdates) can supply one.
  final CatalogItemDto? item;

  factory AliasCandidateDto.fromJson(Map<String, dynamic> j) =>
      AliasCandidateDto(
        names: [for (final n in (j['names'] as List?) ?? const []) '$n'],
        al: (j['al'] as num?)?.toInt(),
        mal: (j['mal'] as num?)?.toInt(),
        lang: j['lang'] as String?,
        item: j['item'] is Map
            ? CatalogItemDto(Map<String, dynamic>.from(j['item'] as Map))
            : null,
      );
}

class CatalogPageDto {
  const CatalogPageDto(this.items, this.hasNext);
  final List<CatalogItemDto> items;
  final bool hasNext;
}

class WatchProvidersDto {
  const WatchProvidersDto({
    required this.link,
    required this.stream,
    required this.free,
    required this.rent,
    required this.buy,
  });

  final String? link;
  final List<String> stream;
  final List<String> free;
  final List<String> rent;
  final List<String> buy;

  bool get isEmpty =>
      stream.isEmpty && free.isEmpty && rent.isEmpty && buy.isEmpty;

  factory WatchProvidersDto.fromJson(Map<String, dynamic> j) {
    List<String> l(String k) => List<String>.from((j[k] as List?) ?? const []);
    return WatchProvidersDto(
      link: j['link'] as String?,
      stream: l('stream'),
      free: l('free'),
      rent: l('rent'),
      buy: l('buy'),
    );
  }

  Map<String, dynamic> toJson() => {
    'link': link,
    'stream': stream,
    'free': free,
    'rent': rent,
    'buy': buy,
  };
}

/// Why a catalog call failed. Codes only; never request content.
class CatalogUnavailable implements Exception {
  const CatalogUnavailable(this.code);

  /// offline, not_configured, rate_limited, upstream_error, bad_response...
  final String code;

  @override
  String toString() => 'CatalogUnavailable($code)';
}

/// One title to match, as sent to the Worker.
class MatchQuery {
  const MatchQuery(
    this.q, [
    this.kind,
    this.screenOnly = false,
    this.adult = false,
  ]);
  final String q;
  final MediaKind? kind;

  /// Shows and films only: never match a comic.
  final bool screenOnly;

  /// Look among adult-rated entries only (AniList), to explain a miss.
  final bool adult;
}

class MatchResponse {
  const MatchResponse(this.results, this.mal, {this.failed = const {}});

  /// Query positions whose lookup failed (offline, busy): not "no match".
  final Set<int> failed;

  /// Candidates per query, in order.
  final List<List<CatalogItemDto>> results;

  /// Titles found by MAL id.
  final List<CatalogItemDto> mal;
}

/// Which sign-in sources the Worker has client ids for.
class OAuthConfigDto {
  const OAuthConfigDto({this.mal});
  final String? mal;
}

abstract class CatalogGateway {
  /// Other names (and AniList and MAL ids) for comics, up to 8 per call.
  /// [source] is `mangadex` or `mangaupdates` (better for Chinese names).
  Future<List<List<AliasCandidateDto>>> aliases(
    List<String> names, {
    String source = 'mangadex',
  });

  /// Titles by AniList id, 50 per call.
  Future<List<CatalogItemDto>> byAniListIds(
    List<int> ids, {
    required bool anime,
  });

  Future<OAuthConfigDto> oauthConfig();

  /// Exchanges an authorization code; returns the access token.
  Future<String> exchangeCode(
    String provider, {
    required String code,
    required String redirectUri,
    String? codeVerifier,
  });

  /// A public list by username (AniList: no key; MAL: client id).
  Future<List<Map<String, dynamic>>> listByUser(String provider, String name);

  /// The signed-in person's list. The token is sent once, then dropped.
  Future<List<Map<String, dynamic>>> listSignedIn(
    String provider,
    String token,
  );

  /// The account name behind a sign-in token, or null when unknown.
  Future<String?> signedInName(String provider, String token);

  /// Batch match for imports: up to 15 titles and 50 MAL ids per type.
  Future<MatchResponse> match(
    List<MatchQuery> items, {
    List<int> malAnime = const [],
    List<int> malManga = const [],
  });

  Future<CatalogPageDto> discover(MediaKind kind, {String? mood, int page = 1});
  Future<CatalogItemDto?> title(String provider, String id, {String? type});
  Future<List<CatalogItemDto>> search(String query, {MediaKind? kind});
  Future<WatchProvidersDto> providers(
    String tmdbId,
    String type,
    String region,
  );

  /// URL to load a poster from on this platform.
  String imageUrl(String posterUrl);
}

/// Talks to the Cue Worker. Fixed endpoints only; 8 s client timeout.
class HttpCatalogGateway implements CatalogGateway {
  HttpCatalogGateway(this.base, {http.Client? client, this.proxyImages = false})
    : _client = client ?? http.Client();

  final String base;
  final http.Client _client;

  /// Web needs posters through the Worker so canvases can draw them.
  final bool proxyImages;

  Future<Object?> _get(String path, Map<String, String> query) async {
    final uri = Uri.parse('$base$path')
        .replace(queryParameters: query.isEmpty ? null : query);
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw const CatalogUnavailable('offline');
    } on Exception {
      throw const CatalogUnavailable('offline');
    }
    if (res.statusCode == 404) return null;
    Object? body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw const CatalogUnavailable('bad_response');
    }
    if (res.statusCode != 200) {
      final code = body is Map ? body['error'] as String? : null;
      throw CatalogUnavailable(code ?? 'http_${res.statusCode}');
    }
    return body;
  }

  Future<Object?> _send(http.Request req) async {
    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _client.send(req).timeout(const Duration(seconds: 30)),
      );
    } on TimeoutException {
      throw const CatalogUnavailable('offline');
    } on Exception {
      throw const CatalogUnavailable('offline');
    }
    Object? body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw const CatalogUnavailable('bad_response');
    }
    if (res.statusCode != 200) {
      final code = body is Map ? body['error'] as String? : null;
      throw CatalogUnavailable(code ?? 'http_${res.statusCode}');
    }
    return body;
  }

  @override
  Future<List<List<AliasCandidateDto>>> aliases(
    List<String> names, {
    String source = 'mangadex',
  }) async {
    final req = http.Request('POST', Uri.parse('$base/catalog/aliases'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'items': [
          for (final n in names.take(8))
            {'q': n.length > 160 ? n.substring(0, 160) : n},
        ],
        'source': source,
      });
    final b = await _send(req) as Map;
    return [
      for (final r in (b['results'] as List?) ?? const [])
        [
          for (final c in (r as List))
            AliasCandidateDto.fromJson(Map<String, dynamic>.from(c as Map)),
        ],
    ];
  }

  /// AniList is reached by the hybrid gateway, never through the Worker.
  @override
  Future<List<CatalogItemDto>> byAniListIds(
    List<int> ids, {
    required bool anime,
  }) async => const [];

  @override
  Future<OAuthConfigDto> oauthConfig() async {
    final b = (await _get('/oauth/config', const {})) as Map? ?? const {};
    return OAuthConfigDto(mal: b['mal'] as String?);
  }

  @override
  Future<String> exchangeCode(
    String provider, {
    required String code,
    required String redirectUri,
    String? codeVerifier,
  }) async {
    final req = http.Request('POST', Uri.parse('$base/oauth/$provider/token'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'code': code,
        'redirectUri': redirectUri,
        'codeVerifier': ?codeVerifier,
      });
    final b = await _send(req) as Map;
    return b['accessToken'] as String;
  }

  List<Map<String, dynamic>> _entries(Object? body) => [
    for (final e in ((body as Map?)?['entries'] as List?) ?? const [])
      Map<String, dynamic>.from(e as Map),
  ];

  @override
  Future<List<Map<String, dynamic>>> listByUser(
    String provider,
    String name,
  ) async => _entries(
    await _get('/import/$provider/user/${Uri.encodeComponent(name)}', const {}),
  );

  @override
  Future<List<Map<String, dynamic>>> listSignedIn(
    String provider,
    String token,
  ) async {
    final req = http.Request('POST', Uri.parse('$base/import/$provider/list'))
      ..headers['Authorization'] = 'Bearer $token';
    return _entries(await _send(req));
  }

  @override
  Future<String?> signedInName(String provider, String token) async {
    final req = http.Request('POST', Uri.parse('$base/import/$provider/me'))
      ..headers['Authorization'] = 'Bearer $token';
    final b = await _send(req);
    return b is Map ? b['name'] as String? : null;
  }

  @override
  Future<MatchResponse> match(
    List<MatchQuery> items, {
    List<int> malAnime = const [],
    List<int> malManga = const [],
  }) async {
    final uri = Uri.parse('$base/catalog/match');
    final http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'items': [
                for (final i in items)
                  {
                    'q': i.q.length > 160 ? i.q.substring(0, 160) : i.q,
                    if (i.kind != null && i.kind != MediaKind.unknown)
                      'kind': i.kind!.name,
                  },
              ],
              'malAnime': malAnime,
              'malManga': malManga,
            }),
          )
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const CatalogUnavailable('offline');
    } on Exception {
      throw const CatalogUnavailable('offline');
    }
    if (res.statusCode != 200) {
      throw CatalogUnavailable('http_${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
    List<CatalogItemDto> list(Object? l) => [
      for (final i in (l as List?) ?? const [])
        CatalogItemDto(Map<String, dynamic>.from(i as Map)),
    ];
    return MatchResponse([
      for (final r in (body['results'] as List?) ?? const []) list(r),
    ], list(body['mal']));
  }

  List<CatalogItemDto> _items(Object? body) => [
    for (final i in ((body as Map?)?['items'] as List?) ?? const [])
      CatalogItemDto(Map<String, dynamic>.from(i as Map)),
  ];

  @override
  Future<CatalogPageDto> discover(
    MediaKind kind, {
    String? mood,
    int page = 1,
  }) async {
    final body = await _get('/catalog/discover', {
      'kind': kind.name,
      'mood': ?mood,
      'page': '$page',
    });
    return CatalogPageDto(_items(body), (body as Map?)?['hasNext'] == true);
  }

  @override
  Future<CatalogItemDto?> title(
    String provider,
    String id, {
    String? type,
  }) async {
    final body = await _get('/catalog/title/$provider/$id', {'type': ?type});
    return body == null
        ? null
        : CatalogItemDto(Map<String, dynamic>.from(body as Map));
  }

  @override
  Future<List<CatalogItemDto>> search(String query, {MediaKind? kind}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final body = await _get('/catalog/search', {
      'q': q.length > 200 ? q.substring(0, 200) : q,
      'kind': ?kind?.name,
    });
    return _items(body);
  }

  @override
  Future<WatchProvidersDto> providers(
    String tmdbId,
    String type,
    String region,
  ) async {
    final body = await _get('/catalog/providers/$tmdbId', {
      'type': type,
      'region': region,
    });
    return WatchProvidersDto.fromJson(
      Map<String, dynamic>.from((body as Map?) ?? const {}),
    );
  }

  @override
  String imageUrl(String posterUrl) => proxyImages
      ? Uri.parse('$base/catalog/image')
            .replace(queryParameters: {'u': posterUrl})
            .toString()
      : posterUrl;
}

/// Routes anime and reading kinds to AniList on the device (AniList blocks
/// Cloudflare Workers) and everything else to the Cue Worker.
class HybridCatalogGateway implements CatalogGateway {
  HybridCatalogGateway(this.worker, this.anilist, {this.web = false});

  final HttpCatalogGateway worker;
  final AniListClient anilist;

  /// Web builds load non-AniList posters through the Worker for CORS.
  final bool web;

  bool _ani(MediaKind? k) => k != null && AniListClient.kinds.contains(k);

  @override
  Future<CatalogPageDto> discover(
    MediaKind kind, {
    String? mood,
    int page = 1,
  }) => _ani(kind)
      ? anilist.discover(kind, mood: mood, page: page)
      : worker.discover(kind, mood: mood, page: page);

  @override
  Future<CatalogItemDto?> title(String provider, String id, {String? type}) =>
      provider == 'anilist'
      ? anilist.title(id)
      : worker.title(provider, id, type: type);

  @override
  Future<List<CatalogItemDto>> search(String query, {MediaKind? kind}) async {
    if (_ani(kind)) return anilist.search(query, kind: kind);
    if (kind != null) return worker.search(query, kind: kind);
    final results = await Future.wait([
      anilist.search(query).catchError((Object _) => <CatalogItemDto>[]),
      worker.search(query).catchError((Object _) => <CatalogItemDto>[]),
    ]);
    return [...results[0].take(6), ...results[1].take(6)];
  }

  @override
  Future<MatchResponse> match(
    List<MatchQuery> items, {
    List<int> malAnime = const [],
    List<int> malManga = const [],
  }) async {
    final out = [for (final _ in items) <CatalogItemDto>[]];
    final aniIdx = [
      for (var i = 0; i < items.length; i++)
        if (_ani(items[i].kind) || items[i].kind == null || items[i].adult) i,
    ];
    final screenIdx = [
      for (var i = 0; i < items.length; i++)
        if (!_ani(items[i].kind) && !items[i].adult) i,
    ];
    if (aniIdx.isNotEmpty) {
      final r = await anilist.searchMany([for (final i in aniIdx) items[i]]);
      for (var j = 0; j < aniIdx.length; j++) {
        out[aniIdx[j]].addAll(r[j]);
      }
    }
    final failed = <int>{};
    // Smaller batches, each retried once: a cold catalog can be slow, and a
    // failed batch is reported as "not checked", never as "no match".
    for (var s = 0; s < screenIdx.length; s += 8) {
      final chunk = screenIdx.skip(s).take(8).toList();
      var ok = false;
      for (var attempt = 0; attempt < 2 && !ok; attempt++) {
        try {
          final r = await worker.match([for (final i in chunk) items[i]]);
          for (var j = 0; j < chunk.length && j < r.results.length; j++) {
            out[chunk[j]].addAll(r.results[j]);
          }
          ok = true;
        } on CatalogUnavailable {
          // Try once more, then give up on this batch.
        }
      }
      if (!ok) failed.addAll(chunk);
    }
    final mal = [
      ...await anilist.byMalIds(malAnime, 'ANIME'),
      ...await anilist.byMalIds(malManga, 'MANGA'),
    ];
    return MatchResponse(out, mal, failed: failed);
  }

  @override
  Future<WatchProvidersDto> providers(
    String tmdbId,
    String type,
    String region,
  ) => worker.providers(tmdbId, type, region);

  @override
  String imageUrl(String posterUrl) {
    if (!web) return posterUrl;
    // AniList's image CDN allows Cue's origin; others go through the Worker.
    return Uri.tryParse(posterUrl)?.host == 's4.anilist.co'
        ? posterUrl
        : worker.imageUrl(posterUrl);
  }

  @override
  Future<List<List<AliasCandidateDto>>> aliases(
    List<String> names, {
    String source = 'mangadex',
  }) => worker.aliases(names, source: source);

  @override
  Future<List<CatalogItemDto>> byAniListIds(
    List<int> ids, {
    required bool anime,
  }) => anilist.byIds(ids, anime: anime);

  @override
  Future<OAuthConfigDto> oauthConfig() => worker.oauthConfig();

  @override
  Future<String> exchangeCode(
    String provider, {
    required String code,
    required String redirectUri,
    String? codeVerifier,
  }) => worker.exchangeCode(
    provider,
    code: code,
    redirectUri: redirectUri,
    codeVerifier: codeVerifier,
  );

  @override
  Future<List<Map<String, dynamic>>> listByUser(String provider, String name) =>
      provider == 'anilist'
      ? anilist.lists(name: name)
      : worker.listByUser(provider, name);

  @override
  Future<List<Map<String, dynamic>>> listSignedIn(
    String provider,
    String token,
  ) => provider == 'anilist'
      ? anilist.lists(token: token)
      : worker.listSignedIn(provider, token);

  @override
  Future<String?> signedInName(String provider, String token) =>
      provider == 'anilist'
      ? anilist.viewerName(token)
      : worker.signedInName(provider, token);
}
