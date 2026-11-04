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
  const CatalogUnavailable(this.code, {this.retryAfter});

  /// How long the provider asked us to wait, when it said so (Retry-After).
  final Duration? retryAfter;

  /// offline, not_configured, rate_limited, upstream_error, bad_response...
  final String code;

  @override
  String toString() => 'CatalogUnavailable($code)';
}

/// Search can still offer usable candidates when one source failed.
class CatalogSearchIncomplete extends CatalogUnavailable {
  const CatalogSearchIncomplete(super.code, this.items);
  final List<CatalogItemDto> items;
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

/// A liked title to ask a provider about: "what do people who liked this
/// also like?". Only the provider id leaves the device.
class SeedRef {
  const SeedRef(this.provider, this.providerId, [this.providerKind]);
  final String provider;
  final String providerId;

  /// TMDB's tv or movie; empty or null elsewhere.
  final String? providerKind;

  @override
  bool operator ==(Object other) =>
      other is SeedRef &&
      other.provider == provider &&
      other.providerId == providerId &&
      (other.providerKind ?? '') == (providerKind ?? '');

  @override
  int get hashCode => Object.hash(provider, providerId, providerKind ?? '');
}

/// Which sign-in sources the Worker has client ids for.
/// Tokens from a sign-in or a renewal. Only ever kept on the device.
class OAuthTokens {
  const OAuthTokens(this.access, {this.refresh, this.expiresAt});
  final String access;
  final String? refresh;
  final DateTime? expiresAt;

  factory OAuthTokens.fromJson(Map<dynamic, dynamic> b) {
    final s = (b['expiresIn'] as num?)?.toInt();
    return OAuthTokens(
      b['accessToken'] as String,
      refresh: b['refreshToken'] as String?,
      expiresAt: s == null ? null : DateTime.now().add(Duration(seconds: s)),
    );
  }
}

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

  /// Exchanges an authorization code for tokens.
  Future<OAuthTokens> exchangeCode(
    String provider, {
    required String code,
    required String redirectUri,
    String? codeVerifier,
  });

  /// Renews tokens with a refresh token.
  Future<OAuthTokens> refreshTokens(String provider, String refreshToken);

  /// A public list by username (AniList: no key; MAL: client id).
  Future<List<Map<String, dynamic>>> listByUser(String provider, String name);

  /// The signed-in person's list. The token is sent once, then dropped.
  Future<List<Map<String, dynamic>>> listSignedIn(
    String provider,
    String token,
  );

  /// The account name behind a sign-in token, or null when unknown.
  Future<String?> signedInName(String provider, String token);

  /// Opt-in AI hints for a typed mood sentence: features to lean toward and
  /// to avoid, limited to [allowed].
  Future<(List<String>, List<String>)> moodHints(
    String text,
    List<String> allowed,
  );

  /// Batch match for imports: up to 15 titles and 50 MAL ids per type.
  Future<MatchResponse> match(
    List<MatchQuery> items, {
    List<int> malAnime = const [],
    List<int> malManga = const [],
  });

  /// One discover page. [sort] picks one of [discoverSorts] for the kind;
  /// null is the provider's default order.
  Future<CatalogPageDto> discover(
    MediaKind kind, {
    String? mood,
    int page = 1,
    String? sort,
  });

  /// Orders discovery can page through for a kind, each with its own
  /// cursor. A single null means the provider has only its default order.
  List<String?> discoverSorts(MediaKind kind);

  /// Provider "more like this" lists, one per seed in order. Providers
  /// without such a list (or without a key) answer an empty list.
  Future<List<List<CatalogItemDto>>> recommendations(List<SeedRef> seeds);
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

  static Duration? _retryAfter(http.Response res) {
    final s = int.tryParse(res.headers['retry-after'] ?? '');
    return s == null || s < 0 ? null : Duration(seconds: s);
  }

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
      throw CatalogUnavailable(
        code ?? 'http_${res.statusCode}',
        retryAfter: _retryAfter(res),
      );
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
      throw CatalogUnavailable(
        code ?? 'http_${res.statusCode}',
        retryAfter: _retryAfter(res),
      );
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
  Future<OAuthTokens> exchangeCode(
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
    return OAuthTokens.fromJson(await _send(req) as Map);
  }

  @override
  Future<OAuthTokens> refreshTokens(
    String provider,
    String refreshToken,
  ) async {
    final req = http.Request('POST', Uri.parse('$base/oauth/$provider/refresh'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({'refreshToken': refreshToken});
    return OAuthTokens.fromJson(await _send(req) as Map);
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
  Future<(List<String>, List<String>)> moodHints(
    String text,
    List<String> allowed,
  ) async {
    final req = http.Request('POST', Uri.parse('$base/ai/mood'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'text': text.length > 200 ? text.substring(0, 200) : text,
        'allowed': allowed.take(200).toList(),
      });
    final b = await _send(req);
    List<String> list(Object? v) => [
      for (final x in (v as List?) ?? const []) '$x',
    ];
    return b is Map
        ? (list(b['features']), list(b['avoid']))
        : (<String>[], <String>[]);
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

  /// The Worker's sources have one order each.
  @override
  List<String?> discoverSorts(MediaKind kind) => const [null];

  /// TMDB titles only; anything else, or a Worker without a TMDB key,
  /// answers empty lists.
  @override
  Future<List<List<CatalogItemDto>>> recommendations(
    List<SeedRef> seeds,
  ) async => [
    for (final seed in seeds)
      seed.provider == 'tmdb'
          ? _items(
              await _get('/catalog/recommendations/tmdb/${seed.providerId}', {
                'type': ?seed.providerKind,
              }),
            )
          : const <CatalogItemDto>[],
  ];

  @override
  Future<CatalogPageDto> discover(
    MediaKind kind, {
    String? mood,
    int page = 1,
    String? sort,
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
    String? sort,
  }) => _ani(kind)
      ? anilist.discover(kind, mood: mood, page: page, sort: sort)
      : worker.discover(kind, mood: mood, page: page);

  @override
  List<String?> discoverSorts(MediaKind kind) =>
      _ani(kind) ? AniListClient.sorts : worker.discoverSorts(kind);

  /// AniList seeds go to AniList in a few batched requests; TMDB seeds go
  /// to the Worker one by one. A failed source leaves its seeds empty only
  /// when the other source succeeded; otherwise the failure is reported.
  @override
  Future<List<List<CatalogItemDto>>> recommendations(
    List<SeedRef> seeds,
  ) async {
    final out = [for (final _ in seeds) <CatalogItemDto>[]];
    final ani = [
      for (var i = 0; i < seeds.length; i++)
        if (seeds[i].provider == 'anilist' &&
            int.tryParse(seeds[i].providerId) != null)
          i,
    ];
    final screen = [
      for (var i = 0; i < seeds.length; i++)
        if (seeds[i].provider == 'tmdb') i,
    ];
    CatalogUnavailable? failure;
    var succeeded = false;
    if (ani.isNotEmpty) {
      try {
        final r = await anilist.recommendations([
          for (final i in ani) int.parse(seeds[i].providerId),
        ]);
        for (var j = 0; j < ani.length && j < r.length; j++) {
          out[ani[j]].addAll(r[j]);
        }
        succeeded = true;
      } on CatalogUnavailable catch (e) {
        failure = e;
      }
    }
    if (screen.isNotEmpty) {
      try {
        final r = await worker.recommendations([
          for (final i in screen) seeds[i],
        ]);
        for (var j = 0; j < screen.length && j < r.length; j++) {
          out[screen[j]].addAll(r[j]);
        }
        succeeded = true;
      } on CatalogUnavailable catch (e) {
        failure ??= e;
      }
    }
    if (failure != null && !succeeded) throw failure;
    return out;
  }

  @override
  Future<CatalogItemDto?> title(String provider, String id, {String? type}) =>
      provider == 'anilist'
      ? anilist.title(id)
      : worker.title(provider, id, type: type);

  @override
  Future<List<CatalogItemDto>> search(String query, {MediaKind? kind}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final wanted = kind == MediaKind.unknown ? null : kind;
    final failures = <String>[];
    Future<List<CatalogItemDto>> attempt(
      Future<List<CatalogItemDto>> Function() load,
    ) async {
      try {
        return await load();
      } on CatalogSearchIncomplete catch (e) {
        failures.add(e.code);
        return e.items;
      } on CatalogUnavailable catch (e) {
        failures.add(e.code);
        return const [];
      }
    }

    final results = await Future.wait([
      if (wanted == null || wanted == MediaKind.anime)
        attempt(() => anilist.search(q, kind: MediaKind.anime)),
      if (wanted == null || wanted.isReading)
        attempt(() => anilist.search(q, kind: MediaKind.manga)),
      if (wanted == null || !_ani(wanted))
        attempt(() => worker.search(q, kind: wanted)),
      if (wanted == null || wanted.isReading) attempt(() => _searchAliases(q)),
    ]);
    final byId = <String, CatalogItemDto>{};
    for (final item in results.expand((r) => r)) {
      if (item.json['adult'] != true &&
          item.json['format'] != 'NOVEL' &&
          item.json['format'] != 'MUSIC') {
        byId.putIfAbsent(item.titleId, () => item);
      }
    }
    final items = byId.values.toList();
    if (failures.isNotEmpty) {
      throw CatalogSearchIncomplete(failures.first, items);
    }
    return items;
  }

  Future<List<CatalogItemDto>> _searchAliases(String query) async {
    final items = <CatalogItemDto>[];
    CatalogUnavailable? failure;
    final al = <int>{};
    final mal = <int>{};
    for (final source in ['mangadex', 'mangaupdates']) {
      try {
        final groups = await aliases([query], source: source);
        for (final candidate in groups.expand((g) => g).take(5)) {
          if (candidate.item case final item?) {
            if (item.kind.isReading) items.add(item);
          }
          if (candidate.al case final id?) {
            al.add(id);
          } else if (candidate.mal case final id?) {
            mal.add(id);
          }
        }
      } on CatalogUnavailable catch (e) {
        failure ??= e;
      }
    }
    for (final load in <Future<List<CatalogItemDto>> Function()>[
      if (al.isNotEmpty) () => anilist.byIds(al.toList(), anime: false),
      if (mal.isNotEmpty) () => anilist.byMalIds(mal.toList(), 'MANGA'),
    ]) {
      try {
        items.addAll(await load());
      } on CatalogUnavailable catch (e) {
        failure ??= e;
      }
    }
    if (failure != null) {
      throw CatalogSearchIncomplete(failure.code, items);
    }
    return items;
  }

  @override
  Future<MatchResponse> match(
    List<MatchQuery> items, {
    List<int> malAnime = const [],
    List<int> malManga = const [],
  }) async {
    final out = [for (final _ in items) <CatalogItemDto>[]];
    final failed = <int>{};
    final aniIdx = [
      for (var i = 0; i < items.length; i++)
        if (_ani(items[i].kind) ||
            items[i].kind == null ||
            items[i].kind == MediaKind.unknown ||
            items[i].adult)
          i,
    ];
    final screenIdx = [
      for (var i = 0; i < items.length; i++)
        if (!_ani(items[i].kind) && !items[i].adult) i,
    ];
    if (aniIdx.isNotEmpty) {
      try {
        final r = await anilist.searchMany([for (final i in aniIdx) items[i]]);
        for (var j = 0; j < aniIdx.length; j++) {
          out[aniIdx[j]].addAll(r[j]);
        }
      } on CatalogUnavailable {
        failed.addAll(aniIdx);
      }
    }
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
  Future<OAuthTokens> refreshTokens(String provider, String refreshToken) =>
      worker.refreshTokens(provider, refreshToken);

  @override
  Future<OAuthTokens> exchangeCode(
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
  Future<(List<String>, List<String>)> moodHints(
    String text,
    List<String> allowed,
  ) => worker.moodHints(text, allowed);

  @override
  Future<String?> signedInName(String provider, String token) =>
      provider == 'anilist'
      ? anilist.viewerName(token)
      : worker.signedInName(provider, token);
}
