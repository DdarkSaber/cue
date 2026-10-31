import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models/title.dart';
import 'catalog_gateway.dart';

/// AniList, called directly from the device. AniList refuses requests from
/// Cloudflare Workers, allows any browser origin (CORS) and needs no key,
/// so these fixed, public, read-only queries run here instead of the Worker.
/// Only titles, ids and public usernames are ever sent.
class AniListClient {
  AniListClient({
    http.Client? client,
    Future<void> Function(Duration)? sleep,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _sleep = sleep ?? Future<void>.delayed,
       _now = clock ?? DateTime.now;
  final http.Client _client;
  final Future<void> Function(Duration) _sleep;
  final DateTime Function() _now;

  /// Minimum gap between calls. AniList currently allows 30 a minute; the
  /// gap follows whatever limit its response headers report.
  Duration _gap = Duration.zero;
  DateTime? _last;

  Future<void> _pace() async {
    final last = _last;
    if (last != null && _gap > Duration.zero) {
      final wait = _gap - _now().difference(last);
      if (wait > Duration.zero) await _sleep(wait);
    }
    _last = _now();
  }

  static final endpoint = Uri.parse('https://graphql.anilist.co');

  static const kinds = {
    MediaKind.anime,
    MediaKind.manga,
    MediaKind.manhwa,
    MediaKind.manhua,
  };

  static const moodGenres = {
    'hype': ['Action', 'Sports'],
    'comfort': ['Slice of Life', 'Comedy'],
    'gripping': ['Thriller', 'Mystery', 'Psychological'],
    'feels': ['Romance', 'Drama'],
  };

  static const _fields = '''
  id idMal type format status episodes chapters countryOfOrigin isAdult
  averageScore genres synonyms startDate { year }
  title { romaji english native }
  coverImage { extraLarge large }
  bannerImage
  description(asHtml: false)
  tags { name rank isAdult isMediaSpoiler }
''';

  // Fixed queries. Variables carry the only request-specific values.
  static const _discover =
      '''query (\$page: Int, \$type: MediaType, \$country: CountryCode, \$genres: [String], \$notFormats: [MediaFormat]) {
  Page(page: \$page, perPage: 50) {
    pageInfo { hasNextPage }
    media(type: \$type, countryOfOrigin: \$country, genre_in: \$genres, format_not_in: \$notFormats, isAdult: false, sort: [POPULARITY_DESC]) { $_fields }
  }
}''';

  static const _title =
      '''query (\$id: Int) {
  Media(id: \$id) {
    $_fields
    relations { edges { relationType node { id type } } }
  }
}''';

  static const _search =
      '''query (\$q: String, \$type: MediaType, \$country: CountryCode) {
  Page(page: 1, perPage: 10) {
    media(search: \$q, type: \$type, countryOfOrigin: \$country, isAdult: false) { $_fields }
  }
}''';

  static const _byMal =
      '''query (\$ids: [Int], \$type: MediaType) {
  Page(page: 1, perPage: 50) {
    media(idMal_in: \$ids, type: \$type) { $_fields }
  }
}''';

  static const _byIds =
      '''query (\$ids: [Int], \$type: MediaType) {
  Page(page: 1, perPage: 50) {
    media(id_in: \$ids, type: \$type) { $_fields }
  }
}''';

  static const _list = '''query (\$name: String, \$type: MediaType) {
  MediaListCollection(userName: \$name, type: \$type) {
    lists { entries {
      status score(format: POINT_10) progress repeat
      completedAt { year month day }
      media { id idMal countryOfOrigin type title { romaji english native } }
    } }
  }
}''';

  static const _viewer = 'query { Viewer { name } }';

  Future<Map<String, dynamic>?> _query(
    String query,
    Map<String, Object?> variables, {
    String? token,
  }) async {
    late http.Response res;
    // A 429 waits as long as AniList asks, then tries again (three times).
    for (var attempt = 0; ; attempt++) {
      await _pace();
      try {
        res = await _client
            .post(
              endpoint,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': ?(token == null ? null : 'Bearer $token'),
              },
              body: jsonEncode({'query': query, 'variables': variables}),
            )
            .timeout(const Duration(seconds: 12));
      } on TimeoutException {
        throw const CatalogUnavailable('offline');
      } on Exception {
        throw const CatalogUnavailable('offline');
      }
      final limit = int.tryParse(res.headers['x-ratelimit-limit'] ?? '');
      if (limit != null && limit > 0) {
        _gap = Duration(milliseconds: (60000 / limit).ceil() + 50);
      }
      if (res.statusCode != 429) break;
      if (attempt >= 3) throw const CatalogUnavailable('rate_limited');
      final after = int.tryParse(res.headers['retry-after'] ?? '') ?? 60;
      // Without a readable header (some browsers hide it) assume the long wait.
      await _sleep(Duration(seconds: after.clamp(1, 65)));
    }
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw const CatalogUnavailable('upstream_error');
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
      return (body['data'] as Map?)?.cast<String, dynamic>();
    } on FormatException {
      throw const CatalogUnavailable('bad_response');
    }
  }

  static ({String type, String? country, List<String> notFormats}) _kind(
    MediaKind kind,
  ) => switch (kind) {
    MediaKind.anime => (type: 'ANIME', country: null, notFormats: ['MUSIC']),
    MediaKind.manhwa => (type: 'MANGA', country: 'KR', notFormats: ['NOVEL']),
    MediaKind.manhua => (type: 'MANGA', country: 'CN', notFormats: ['NOVEL']),
    _ => (type: 'MANGA', country: 'JP', notFormats: ['NOVEL']),
  };

  Future<CatalogPageDto> discover(
    MediaKind kind, {
    String? mood,
    int page = 1,
  }) async {
    final k = _kind(kind);
    final data = await _query(_discover, {
      'page': page,
      'type': k.type,
      'country': k.country,
      'notFormats': k.notFormats,
      'genres': moodGenres[mood],
    });
    final p = data?['Page'] as Map?;
    return CatalogPageDto([
      for (final m in (p?['media'] as List?) ?? const []) normalize(m as Map),
    ], (p?['pageInfo'] as Map?)?['hasNextPage'] == true);
  }

  Future<CatalogItemDto?> title(String id) async {
    final data = await _query(_title, {'id': int.parse(id)});
    final m = data?['Media'] as Map?;
    return m == null ? null : normalize(m);
  }

  Future<List<CatalogItemDto>> search(String q, {MediaKind? kind}) async {
    final k = kind == null ? null : _kind(kind);
    final data = await _query(_search, {
      'q': q,
      'type': k?.type,
      // Manga comes from anywhere; only manhwa and manhua are narrowed.
      'country': kind == MediaKind.manhwa || kind == MediaKind.manhua
          ? k?.country
          : null,
    });
    final p = data?['Page'] as Map?;
    return [
      for (final m in (p?['media'] as List?) ?? const []) normalize(m as Map),
    ];
  }

  /// Several searches in one request (12 x 5 stays under AniList's query
  /// complexity cap of 500). Titles travel as variables only.
  Future<List<List<CatalogItemDto>>> searchMany(List<MatchQuery> items) async {
    if (items.isEmpty) return const [];
    final vars = <String, Object?>{};
    final decls = <String>[];
    final parts = <String>[];
    for (var i = 0; i < items.length; i++) {
      final kind = items[i].kind;
      final k = kind != null && kinds.contains(kind) ? _kind(kind) : null;
      vars['q$i'] = items[i].q;
      decls.add('\$q$i: String');
      final type = k == null ? '' : ', type: ${k.type}';
      final country = kind == MediaKind.manhwa || kind == MediaKind.manhua
          ? ', countryOfOrigin: ${k!.country}'
          : '';
      parts.add(
        's$i: Page(page: 1, perPage: 5) { media(search: \$q$i$type$country, isAdult: false) { $_fields } }',
      );
    }
    final data = await _query(
      'query (${decls.join(', ')}) { ${parts.join(' ')} }',
      vars,
    );
    return [
      for (var i = 0; i < items.length; i++)
        [
          for (final m
              in ((data?['s$i'] as Map?)?['media'] as List?) ?? const [])
            normalize(m as Map),
        ],
    ];
  }

  /// Titles by AniList id, 50 per call. Unknown ids are simply absent.
  Future<List<CatalogItemDto>> byIds(
    List<int> ids, {
    required bool anime,
  }) async {
    if (ids.isEmpty) return const [];
    final data = await _query(_byIds, {
      'ids': ids.take(50).toList(),
      'type': anime ? 'ANIME' : 'MANGA',
    });
    final p = data?['Page'] as Map?;
    return [
      for (final m in (p?['media'] as List?) ?? const []) normalize(m as Map),
    ];
  }

  Future<List<CatalogItemDto>> byMalIds(List<int> ids, String type) async {
    if (ids.isEmpty) return const [];
    final data = await _query(_byMal, {
      'ids': ids.take(50).toList(),
      'type': type,
    });
    final p = data?['Page'] as Map?;
    return [
      for (final m in (p?['media'] as List?) ?? const []) normalize(m as Map),
    ];
  }

  /// A public list by username, or the signed-in viewer's with a token.
  Future<List<Map<String, dynamic>>> lists({
    String? name,
    String? token,
  }) async {
    var user = name;
    if (user == null && token != null) {
      final v = await _query(_viewer, const {}, token: token);
      user = (v?['Viewer'] as Map?)?['name'] as String?;
      if (user == null) throw const CatalogUnavailable('upstream_error');
    }
    final out = <Map<String, dynamic>>[];
    for (final type in ['ANIME', 'MANGA']) {
      final data = await _query(_list, {
        'name': user,
        'type': type,
      }, token: token);
      final groups =
          ((data?['MediaListCollection'] as Map?)?['lists'] as List?) ??
          const [];
      for (final g in groups) {
        for (final e in ((g as Map)['entries'] as List?) ?? const []) {
          out.add(_entry(e as Map));
        }
      }
    }
    return out;
  }

  static Map<String, dynamic> _entry(Map<dynamic, dynamic> e) {
    final m = (e['media'] as Map?) ?? const {};
    final t = (m['title'] as Map?) ?? const {};
    final c = (e['completedAt'] as Map?) ?? const {};
    String? date;
    if (c['year'] != null && c['month'] != null && c['day'] != null) {
      String two(Object? n) => '$n'.padLeft(2, '0');
      date = '${c['year']}-${two(c['month'])}-${two(c['day'])}';
    }
    final score = (e['score'] as num?) ?? 0;
    return {
      'anilistId': m['id'],
      'malId': m['idMal'],
      'title': t['english'] ?? t['romaji'] ?? t['native'] ?? '',
      'kind': m['type'] == 'ANIME'
          ? 'anime'
          : _readingKind(m['countryOfOrigin']),
      'status': '${e['status'] ?? ''}'.toLowerCase(),
      'score': score > 0 ? score : null,
      'scoreScale': score > 0 ? '10' : null,
      'progress': ((e['progress'] as num?) ?? 0) > 0 ? e['progress'] : null,
      'repeat': ((e['repeat'] as num?) ?? 0) > 0 ? e['repeat'] : null,
      'completedAt': date,
    };
  }

  static String _readingKind(Object? country) => switch (country) {
    'KR' => 'manhwa',
    'CN' || 'TW' => 'manhua',
    _ => 'manga',
  };

  static String? _plain(String? raw) {
    if (raw == null) return null;
    final text = raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp('<[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp('&#0?39;|&apos;'), "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (text.isEmpty) return null;
    return text.length > 1200
        ? '${text.substring(0, 1199).trimRight()}…'
        : text;
  }

  static int? _pos(Object? v) => v is num && v > 0 ? v.round() : null;

  /// Same shape the Worker sends, so the rest of the app is unchanged.
  static CatalogItemDto normalize(Map<dynamic, dynamic> m) {
    final tags = ((m['tags'] as List?) ?? const [])
        .cast<Map<dynamic, dynamic>>();
    final relations =
        (((m['relations'] as Map?)?['edges'] as List?) ?? const [])
            .cast<Map<dynamic, dynamic>>();
    final related = [
      for (final e in relations)
        if ((e['relationType'] == 'PREQUEL' || e['relationType'] == 'PARENT') &&
            (e['node'] as Map?)?['type'] == m['type'])
          ((e['node'] as Map)['id'] as num).toInt(),
    ];
    final id = (m['id'] as num).toInt();
    final kind = m['type'] == 'ANIME'
        ? 'anime'
        : _readingKind(m['countryOfOrigin']);
    final status = switch (m['status']) {
      'FINISHED' => 'finished',
      'RELEASING' => m['type'] == 'ANIME' ? 'airing' : 'ongoing',
      'HIATUS' => 'ongoing',
      _ => 'unknown',
    };
    final title = (m['title'] as Map?) ?? const {};
    final cover = (m['coverImage'] as Map?) ?? const {};
    return CatalogItemDto({
      'provider': 'anilist',
      'providerId': '$id',
      'providerKind': null,
      'idMal': _pos(m['idMal']),
      'kind': kind,
      'titleEn': title['english'],
      'titleRomaji': title['romaji'],
      'titleNative': title['native'],
      'year': _pos((m['startDate'] as Map?)?['year']),
      'country': m['countryOfOrigin'],
      'format': m['format'],
      'status': status,
      'episodes': _pos(m['episodes']),
      'chapters': _pos(m['chapters']),
      'seasons': const <Object>[],
      'genres': ((m['genres'] as List?) ?? const []).take(8).toList(),
      // Alternate names, for matching only; not stored in the catalog.
      'synonyms': [
        for (final s in (m['synonyms'] as List?) ?? const [])
          if (s is String && s.trim().isNotEmpty) s,
      ].take(25).toList(),
      'tags': [
        for (final t in tags)
          if (t['isMediaSpoiler'] != true && ((t['rank'] as num?) ?? 0) >= 60)
            '${t['name']}'.toLowerCase(),
      ].take(12).toList(),
      'score': _pos(m['averageScore']),
      'posterUrl': cover['extraLarge'] ?? cover['large'],
      'backdropUrl': m['bannerImage'],
      'synopsis': _plain(m['description'] as String?),
      'adult': m['isAdult'] == true || tags.any((t) => t['isAdult'] == true),
      'franchiseKey': relations.isEmpty
          ? null
          : 'anilist:${[id, ...related].reduce((a, b) => a < b ? a : b)}',
    });
  }
}
