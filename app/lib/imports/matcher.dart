import '../data/catalog_gateway.dart';
import '../data/catalog_repository.dart';
import '../domain/models/title.dart';
import 'records.dart';

/// How a record was tied to a catalog title. Similarity is never shown as a
/// probability: `similar` only means "worth a look" and is never imported
/// without the person ticking it.
enum MatchClass { exactId, confirmed, suggested, similar, unresolved }

class MatchedRecord {
  MatchedRecord(
    this.record,
    this.titleId,
    this.matchClass, {
    this.included = true,
    this.candidate,
    this.unchecked = false,
    this.adultHidden = false,
  });

  final NormalizedRecord record;
  final String? titleId;
  final MatchClass matchClass;

  /// Unticked in the preview (e.g. a Netflix show someone else watched).
  bool included;

  /// For `similar`: the catalog entry offered. It is only added to the
  /// catalog if the person includes it.
  final CatalogItemDto? candidate;

  /// The lookup itself failed (offline, busy); this is not a "no match".
  final bool unchecked;

  /// The title exists but is rated adult, which Cue keeps out of search.
  final bool adultHidden;

  bool get resolved => titleId != null;

  /// Display name of the offered similar title.
  String? get candidateName {
    final j = candidate?.json;
    return (j?['titleEn'] ?? j?['titleRomaji'] ?? j?['titleNative']) as String?;
  }
}

/// Lower-case, punctuation-free form used for exact title comparison.
String normTitle(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[’‘`´]'), "'")
    .replaceAll("'", '')
    .replaceAll(RegExp(r'[^a-z0-9぀-ヿ一-鿿가-힯]+'), ' ')
    .trim();

/// The text sent to a catalog: curly quotes straightened, trailing "(2020)"
/// or "(webtoon)" dropped, and season, part and "all seasons" suffixes
/// removed (a franchise row stands for the whole show).
String cleanQuery(String title, {bool screen = false}) {
  var s = title
      .replaceAll(RegExp('[’‘`´]'), "'")
      .replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '')
      .replaceAll(
        RegExp(
          r'\s+(all seasons|trilogy|complete series)$',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'[\s:–-]+(season|part|cour|series)\s*\d+\s*$',
          caseSensitive: false,
        ),
        '',
      )
      // "2nd Season", "Second Season", "Final Season".
      .replaceAll(
        RegExp(
          r'[\s:–-]+(\d+(st|nd|rd|th)|second|third|fourth|final)\s+season\s*$',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'[\s.,;:]+$'), '')
      .trim();
  // "The Uncanny Counter 2": for shows a bare trailing number is a sequel.
  if (screen) s = s.replaceAll(RegExp(r'\s+\d{1,2}$'), '').trim();
  return s.isEmpty ? title : s;
}

/// Dice coefficient on letter pairs of the spaceless normalised titles, with
/// a floor for a title that is the start of the other at a word boundary.
double similarity(String a, String b) {
  final x = normTitle(a), y = normTitle(b);
  if (x.isEmpty || y.isEmpty) return 0;
  if (x == y) return 1;
  final short = x.length <= y.length ? x : y;
  final long = x.length <= y.length ? y : x;
  if (short.length >= 5 &&
      (long.startsWith('$short ') || long.startsWith(short))) {
    // "A Silent Voice" inside "A Silent Voice: The Movie".
    if (long.startsWith('$short ')) return 0.9;
  }
  final p = x.replaceAll(' ', ''), q = y.replaceAll(' ', '');
  // The same letters with different spacing ("konnani" and "konna ni").
  if (p == q) return 1;
  if (p.length < 2 || q.length < 2) return 0;
  final tokens = _tokenScore(x, y);
  final pairs = <String, int>{};
  for (var i = 0; i < p.length - 1; i++) {
    pairs.update(p.substring(i, i + 2), (n) => n + 1, ifAbsent: () => 1);
  }
  var shared = 0;
  for (var i = 0; i < q.length - 1; i++) {
    final k = q.substring(i, i + 2);
    final n = pairs[k] ?? 0;
    if (n > 0) {
      pairs[k] = n - 1;
      shared++;
    }
  }
  final dice = 2 * shared / ((p.length - 1) + (q.length - 1));
  return dice > tokens ? dice : tokens;
}

const _stop = {
  'the',
  'a',
  'an',
  'of',
  'to',
  'and',
  'in',
  'on',
  'for',
  'with',
  'is',
  'i',
  'my',
  'me',
  'at',
  'as',
  'by',
  'from',
  'that',
  'this',
  'wa',
  'no',
  'ga',
  'ni',
  'wo',
  'de',
};

String _stem(String w) {
  if (w.length > 5 && w.endsWith('ing')) return w.substring(0, w.length - 3);
  if (w.length > 4 && w.endsWith('es')) return w.substring(0, w.length - 2);
  if (w.length > 4 && (w.endsWith('s') || w.endsWith('ed'))) {
    return w.substring(0, w.length - (w.endsWith('s') ? 1 : 2));
  }
  return w;
}

/// Order-free word overlap: "Return of the Frozen Player" and "The Frozen
/// Player Returns" share every meaningful word. A short query whose words all
/// appear in a longer title ("Bunny Girl Senpai") also scores.
double _tokenScore(String x, String y) {
  Set<String> toks(String s) => {
    for (final w in s.split(' '))
      if (w.length > 1 && !_stop.contains(w)) _stem(w),
  };
  final a = toks(x), b = toks(y);
  if (a.length < 3 && b.length < 3) return 0;
  final inter = a.intersection(b).length;
  if (inter == 0) return 0;
  final small = a.length <= b.length ? a : b;
  if (small.length >= 3 && inter == small.length) {
    return a.length == b.length ? 0.95 : 0.8;
  }
  final jaccard = inter / a.union(b).length;
  return jaccard >= 0.8 ? 0.85 : 0;
}

bool _kindFits(MediaKind? wanted, MediaKind got) {
  if (wanted == null || wanted == MediaKind.unknown) return true;
  if (wanted == got) return true;
  // Reading kinds are often mislabelled across sources; keep them together.
  if (wanted.isReading && got.isReading) return true;
  // Dramas and series share one catalog and are told apart by country, which
  // a sheet's "English series" label may not match exactly.
  const screen = {
    MediaKind.series,
    MediaKind.kdrama,
    MediaKind.cdrama,
    MediaKind.jdrama,
  };
  return screen.contains(wanted) && screen.contains(got);
}

/// Resolution order: provider id, then an exact title (kind must fit; a
/// year only breaks ties, because a franchise row's year is often the
/// original work's), then a similar title offered for a tick, else the
/// review queue.
class ImportMatcher {
  ImportMatcher(this.catalog);
  final CatalogRepository catalog;

  /// AniList caps query complexity: 12 titles x 5 results stays under it.
  static const batchSize = 12;
  static const similarThreshold = 0.74;

  Future<List<MatchedRecord>> match(
    List<NormalizedRecord> records, {
    bool offlineOnly = false,
    void Function(int done, int total)? onProgress,
  }) async {
    final out = List<MatchedRecord?>.filled(records.length, null);
    final pending = <int>[];

    // 1. Local identities (free, offline).
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      String? id;
      if (r.cueId != null && await catalog.titleById(r.cueId!) != null) {
        id = r.cueId;
      }
      if (id == null && r.anilistId != null) {
        id = await catalog.findByIdentity('anilist', '${r.anilistId}');
      }
      if (id == null && r.malId != null) {
        id =
            await catalog.findByIdentity('mal', '${r.malId}', 'anime') ??
            await catalog.findByIdentity('mal', '${r.malId}', 'manga');
      }
      if (id != null) {
        out[i] = MatchedRecord(
          r,
          id,
          MatchClass.exactId,
          included: r.confirmed,
        );
      } else {
        pending.add(i);
      }
    }

    // 2. Exact title against the local cache.
    final cached = await catalog.pool(MediaKind.values);
    final byTitle = <String, List<Title>>{};
    for (final t in cached) {
      for (final n in {t.titleEn, t.titleRomaji, t.titleNative}) {
        if (n != null) byTitle.putIfAbsent(normTitle(n), () => []).add(t);
      }
    }
    String? localTitle(NormalizedRecord r) {
      for (final name in {r.title, cleanQuery(r.title), ...r.altTitles}) {
        final hits = [
          for (final t in byTitle[normTitle(name)] ?? const <Title>[])
            if (_kindFits(r.kind, t.kind)) t,
        ];
        if (hits.isEmpty) continue;
        return (hits.where((t) => _yearFits(r.year, t.year)).firstOrNull ??
                hits.first)
            .id;
      }
      return null;
    }

    final remote = <int>[];
    for (final i in pending) {
      final id = localTitle(records[i]);
      if (id != null) {
        out[i] = MatchedRecord(
          records[i],
          id,
          MatchClass.suggested,
          included: records[i].confirmed,
        );
      } else {
        remote.add(i);
      }
    }

    // 3. The catalogs, in batches: MAL ids first, then titles.
    final unchecked = <int>{};
    var done = records.length - remote.length;
    onProgress?.call(done, records.length);
    if (!offlineOnly && remote.isNotEmpty) {
      try {
        await _remote(records, remote, out, unchecked, (n) {
          done += n;
          onProgress?.call(done, records.length);
        });
      } on CatalogUnavailable {
        // Offline mid-way: what is left is reported as not checked.
        unchecked.addAll(remote.where((i) => out[i] == null));
      }
    }

    return [
      for (var i = 0; i < records.length; i++)
        out[i] ??
            MatchedRecord(
              records[i],
              null,
              MatchClass.unresolved,
              included: false,
              unchecked: unchecked.contains(i),
            ),
    ];
  }

  bool _isScreen(MediaKind? k) =>
      k == MediaKind.series ||
      k == MediaKind.kdrama ||
      k == MediaKind.cdrama ||
      k == MediaKind.jdrama ||
      k == MediaKind.movie;

  Future<void> _remote(
    List<NormalizedRecord> records,
    List<int> remote,
    List<MatchedRecord?> out,
    Set<int> unchecked,
    void Function(int) progressed,
  ) async {
    final gateway = catalog.gateway;
    final withMal = remote.where((i) => records[i].malId != null).toList();
    for (var s = 0; s < withMal.length; s += 50) {
      final chunk = withMal.skip(s).take(50).toList();
      final anime = [
        for (final i in chunk)
          if (records[i].kind == MediaKind.anime) records[i].malId!,
      ];
      final manga = [
        for (final i in chunk)
          if (records[i].kind != MediaKind.anime) records[i].malId!,
      ];
      final res = await gateway.match(
        const [],
        malAnime: anime,
        malManga: manga,
      );
      await catalog.upsert(res.mal);
      for (final i in chunk) {
        final id = await catalog.findByIdentity(
          'mal',
          '${records[i].malId}',
          records[i].kind == MediaKind.anime ? 'anime' : 'manga',
        );
        if (id != null) {
          out[i] = MatchedRecord(records[i], id, MatchClass.exactId);
        }
      }
    }

    final byTitle = remote.where((i) => out[i] == null).toList();
    progressed(remote.length - byTitle.length);
    await _titlePass(
      records,
      byTitle,
      (i) => [
        cleanQuery(
          records[i].title,
          screen:
              _isScreen(records[i].kind) && records[i].kind != MediaKind.movie,
        ),
      ],
      out,
      unchecked,
      progressed: progressed,
    );

    // 3b. AniList's search chokes on long or complex titles but finds the
    // show from its first few words, an alternate name from the sheet, or
    // the part before the colon. Try those for what is still unmatched.
    final retry = [
      for (final i in remote)
        if ((out[i] == null || out[i]!.matchClass == MatchClass.similar) &&
            !unchecked.contains(i))
          i,
    ];
    await _titlePass(records, retry, _shorterQueries, out, unchecked);

    // 4. Comics still unmatched (or only similar): ask MangaDex for the
    // work's other names and its AniList link.
    final stuck = [
      for (final i in remote)
        if ((out[i] == null || out[i]!.matchClass == MatchClass.similar) &&
            (records[i].kind?.isReading ?? false) &&
            !unchecked.contains(i))
          i,
    ];
    await _viaAliases(records, stuck, out);

    // 4b. MangaUpdates knows Chinese, Korean and Japanese names the others
    // lack, and can supply a card for a work that is on neither.
    final stillStuck = [
      for (final i in stuck)
        if (out[i] == null || out[i]!.matchClass == MatchClass.similar) i,
    ];
    await _viaMangaUpdates(records, stillStuck, out);

    // 5. Whatever is left may simply be rated adult, which Cue keeps out of
    // search by design. Say so instead of leaving it as an unexplained miss.
    final leftover = [
      for (final i in remote)
        if (out[i] == null && !unchecked.contains(i)) i,
    ];
    await _adultCheck(records, leftover, out);
  }

  /// Looks the unmatched titles up among adult-rated entries only. A hit is
  /// reported as "adult-rated, hidden", never linked.
  Future<void> _adultCheck(
    List<NormalizedRecord> records,
    List<int> idx,
    List<MatchedRecord?> out,
  ) async {
    final gateway = catalog.gateway;
    final candidates = [
      for (final i in idx)
        if (!(records[i].kind?.isReading ?? false) || records[i].kind == null)
          i,
    ];
    for (var s = 0; s < candidates.length; s += batchSize) {
      final chunk = candidates.skip(s).take(batchSize).toList();
      final MatchResponse res;
      try {
        res = await gateway.match([
          for (final i in chunk)
            MatchQuery(
              _shorterQueries(i, records).firstOrNull ??
                  cleanQuery(records[i].title),
              records[i].kind,
              records[i].screenOnly,
              true,
            ),
        ]);
      } on CatalogUnavailable {
        return;
      }
      for (var j = 0; j < chunk.length && j < res.results.length; j++) {
        final r = records[chunk[j]];
        if (_exact(r, res.results[j]) != null ||
            _similar(r, res.results[j]) != null) {
          out[chunk[j]] = MatchedRecord(
            r,
            null,
            MatchClass.unresolved,
            included: false,
            adultHidden: true,
          );
        }
      }
    }
  }

  /// Other forms of a name to search with, most specific first.
  List<String> _shorterQueries(int i, [List<NormalizedRecord>? all]) {
    final r = (all ?? _records)[i];
    final base = cleanQuery(r.title);
    final tried = {normTitle(base)};
    final out = <String>[];
    void add(String q) {
      final c = q.trim();
      if (c.length < 5 || !tried.add(normTitle(c))) return;
      out.add(c);
    }

    for (final alt in r.altTitles.take(1)) {
      add(cleanQuery(alt));
    }
    final beforeColon = base.split(RegExp(r'\s*:\s*')).first;
    if (beforeColon != base && beforeColon.length >= 8) add(beforeColon);
    final words = base.split(RegExp(r'\s+'));
    if (words.length >= 6) add(words.take(4).join(' '));
    if (words.length >= 4) add(words.take(2).join(' '));
    return out.take(4).toList();
  }

  List<NormalizedRecord> _records = const [];

  /// One search per (record, query). A confident match always wins; a
  /// similar one is kept only if nothing better turns up.
  Future<void> _titlePass(
    List<NormalizedRecord> records,
    List<int> idx,
    List<String> Function(int) queriesFor,
    List<MatchedRecord?> out,
    Set<int> unchecked, {
    void Function(int)? progressed,
  }) async {
    _records = records;
    final gateway = catalog.gateway;
    final jobs = <(int, String)>[
      for (final i in idx)
        for (final q in queriesFor(i)) (i, q),
    ];
    for (var s = 0; s < jobs.length; s += batchSize) {
      final chunk = jobs.skip(s).take(batchSize).toList();
      final MatchResponse res;
      try {
        res = await gateway.match([
          for (final (i, q) in chunk)
            MatchQuery(q, records[i].kind, records[i].screenOnly),
        ]);
      } on CatalogUnavailable {
        unchecked.addAll(chunk.map((c) => c.$1));
        progressed?.call(chunk.length);
        continue;
      }
      for (var j = 0; j < chunk.length && j < res.results.length; j++) {
        final idx = chunk[j].$1;
        if (res.failed.contains(j)) {
          unchecked.add(idx);
          continue;
        }
        final r = records[idx];
        if (out[idx] != null && out[idx]!.matchClass != MatchClass.similar) {
          continue;
        }
        final exact = _exact(r, res.results[j]);
        if (exact != null) {
          final ids = await catalog.upsert([exact]);
          out[idx] = MatchedRecord(
            r,
            ids.first,
            MatchClass.suggested,
            included: r.confirmed,
          );
          unchecked.remove(idx);
          continue;
        }
        if (out[idx] != null) continue;
        final like = _similar(r, res.results[j]);
        if (like != null) {
          // Offered, not linked: the catalog row is added only if ticked.
          out[idx] = MatchedRecord(
            r,
            like.titleId,
            MatchClass.similar,
            included: false,
            candidate: like,
          );
        }
      }
      progressed?.call(chunk.length);
    }
  }

  /// MangaUpdates: a work whose associated names include the typed name
  /// becomes the match, using its own card.
  Future<void> _viaMangaUpdates(
    List<NormalizedRecord> records,
    List<int> idx,
    List<MatchedRecord?> out,
  ) async {
    final gateway = catalog.gateway;
    for (var s = 0; s < idx.length; s += 8) {
      final chunk = idx.skip(s).take(8).toList();
      final List<List<AliasCandidateDto>> res;
      try {
        res = await gateway.aliases([
          for (final i in chunk) cleanQuery(records[i].title),
        ], source: 'mangaupdates');
      } on CatalogUnavailable {
        continue;
      }
      for (var j = 0; j < chunk.length && j < res.length; j++) {
        final r = records[chunk[j]];
        final names = _names(r);
        for (final c in res[j]) {
          final item = c.item;
          if (item == null || !_kindFits(r.kind, item.kind)) continue;
          if (!c.names.any((n) => names.contains(_key(n)))) continue;
          final ids = await catalog.upsert([item]);
          out[chunk[j]] = MatchedRecord(
            r,
            ids.first,
            MatchClass.suggested,
            included: r.confirmed,
          );
          break;
        }
      }
    }
  }

  /// Resolves comic names through MangaDex: a MangaDex work whose names
  /// include the typed name (after cleaning) gives an AniList id, which is
  /// then fetched in full. Language narrows manhwa (ko) and manhua (zh).
  Future<void> _viaAliases(
    List<NormalizedRecord> records,
    List<int> idx,
    List<MatchedRecord?> out,
  ) async {
    if (idx.isEmpty) return;
    final gateway = catalog.gateway;
    final wantedAl = <int, int>{}; // record index -> AniList id
    final wantedMal = <int, int>{};
    for (var s = 0; s < idx.length; s += 8) {
      final chunk = idx.skip(s).take(8).toList();
      final List<List<AliasCandidateDto>> res;
      try {
        res = await gateway.aliases([
          for (final i in chunk) cleanQuery(records[i].title),
        ]);
      } on CatalogUnavailable {
        continue;
      }
      for (var j = 0; j < chunk.length && j < res.length; j++) {
        final r = records[chunk[j]];
        final names = _names(r);
        for (final c in res[j]) {
          if (!_langFits(r.kind, c.lang)) continue;
          if (!c.names.any((n) => names.contains(_key(n)))) continue;
          if (c.al != null) {
            wantedAl[chunk[j]] = c.al!;
          } else if (c.mal != null) {
            wantedMal[chunk[j]] = c.mal!;
          } else {
            continue;
          }
          break;
        }
      }
    }
    if (wantedAl.isEmpty && wantedMal.isEmpty) return;
    final found = <int, CatalogItemDto>{};
    try {
      final ids = wantedAl.values.toSet().toList();
      for (var s = 0; s < ids.length; s += 50) {
        for (final d in await gateway.byAniListIds(
          ids.skip(s).take(50).toList(),
          anime: false,
        )) {
          found[int.parse(d.providerId)] = d;
        }
      }
      final mals = wantedMal.values.toSet().toList();
      final byMal = <int, CatalogItemDto>{};
      for (var s = 0; s < mals.length; s += 50) {
        final res = await gateway.match(
          const [],
          malManga: mals.skip(s).take(50).toList(),
        );
        for (final d in res.mal) {
          if (d.idMal != null) byMal[d.idMal!] = d;
        }
      }
      for (final e in wantedMal.entries) {
        final d = byMal[e.value];
        if (d != null) found[int.parse(d.providerId)] = d;
        wantedAl[e.key] = d == null ? 0 : int.parse(d.providerId);
      }
    } on CatalogUnavailable {
      return;
    }
    for (final e in wantedAl.entries) {
      final d = found[e.value];
      if (d == null || !_kindFits(records[e.key].kind, d.kind)) continue;
      final ids = await catalog.upsert([d]);
      out[e.key] = MatchedRecord(
        records[e.key],
        ids.first,
        MatchClass.suggested,
        included: records[e.key].confirmed,
      );
    }
  }

  /// Manhwa are Korean and manhua Chinese; manga and unlabelled comics can
  /// come from anywhere.
  static bool _langFits(MediaKind? kind, String? lang) {
    if (lang == null) return true;
    return switch (kind) {
      MediaKind.manhwa => lang == 'ko',
      MediaKind.manhua => lang.startsWith('zh'),
      _ => true,
    };
  }

  /// Spaceless key: "Konnani" and "Konna ni" are the same name.
  static String _key(String s) => normTitle(s).replaceAll(' ', '');

  Set<String> _names(NormalizedRecord r) => {
    for (final n in [
      r.title,
      cleanQuery(r.title),
      cleanQuery(r.title, screen: true),
      ...r.altTitles,
    ])
      _key(n),
  };

  /// Titles and alternate names (AniList synonyms) of a candidate.
  Iterable<String> _candidateNames(CatalogItemDto c) => c.names;

  /// A long name that starts another ("Rakudai Kenja no Gakuin Musou" inside
  /// its full romaji): four words and 24 letters are enough to be unique.
  bool _longPrefix(NormalizedRecord r, CatalogItemDto c) {
    final mine = [
      for (final n in [r.title, cleanQuery(r.title), ...r.altTitles])
        normTitle(n),
    ];
    for (final cand in _candidateNames(c).map(normTitle)) {
      for (final m in mine) {
        final short = m.length <= cand.length ? m : cand;
        final long = m.length <= cand.length ? cand : m;
        if (short.split(' ').length >= 4 &&
            short.length >= 24 &&
            long.startsWith('$short ')) {
          return true;
        }
      }
    }
    return false;
  }

  bool _allowed(NormalizedRecord r, CatalogItemDto c) =>
      _kindFits(r.kind, c.kind) && !(r.screenOnly && c.kind.isReading);

  /// The first candidate whose title equals one of the record's names.
  /// Several exact titles (two shows called "Big Mouth") are told apart by
  /// year and kind.
  CatalogItemDto? _exact(NormalizedRecord r, List<CatalogItemDto> candidates) {
    final names = _names(r);
    var hits = [
      for (final c in candidates)
        if (_allowed(r, c) &&
            _candidateNames(c).any((n) => names.contains(_key(n))))
          c,
    ];
    if (hits.isEmpty) {
      hits = [
        for (final c in candidates)
          if (_allowed(r, c) && _longPrefix(r, c)) c,
      ];
    }
    if (hits.isEmpty) return null;
    if (hits.length == 1) return hits.first;
    CatalogItemDto? best;
    for (final c in hits) {
      final sameKind = r.kind == null || c.kind == r.kind;
      final yearOk = _yearFits(r.year, (c.json['year'] as num?)?.toInt());
      if (sameKind && yearOk) return c;
      best ??= sameKind ? c : null;
    }
    return best ?? hits.first;
  }

  /// The most similar candidate above the threshold, for review.
  CatalogItemDto? _similar(
    NormalizedRecord r,
    List<CatalogItemDto> candidates,
  ) {
    final queries = [r.title, cleanQuery(r.title), ...r.altTitles];
    CatalogItemDto? best;
    var bestScore = similarThreshold;
    for (final c in candidates) {
      if (!_allowed(r, c)) continue;
      var score = 0.0;
      for (final q in queries) {
        for (final n in _candidateNames(c)) {
          final s = similarity(q, n);
          if (s > score) score = s;
        }
      }
      if (score > bestScore) {
        best = c;
        bestScore = score;
      }
    }
    return best;
  }

  static bool _yearFits(int? a, int? b) =>
      a == null || b == null || (a - b).abs() <= 1;
}
