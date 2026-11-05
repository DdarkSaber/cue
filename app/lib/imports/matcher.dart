import '../data/catalog_gateway.dart';
import '../data/catalog_repository.dart';
import '../domain/models/title.dart';
import '../domain/title_names.dart';
import 'records.dart';

export '../domain/title_names.dart' show normTitle;

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

/// The text sent to a catalog: curly quotes straightened, trailing "(2020)"
/// or "(webtoon)" dropped, and season, part and "all seasons" suffixes
/// removed (a franchise row stands for the whole show).
String cleanQuery(
  String title, {
  bool screen = false,
  bool preserveParts = false,
}) {
  var s = title
      .replaceAll(RegExp('[’‘`´]'), "'")
      .replaceAll(
        RegExp(
          preserveParts
              ? r'\s*\((?:\d{4}|webtoon|anime|manga|manhwa|manhua)\)\s*$'
              : r'\s*\([^)]*\)\s*$',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
  if (!preserveParts) {
    s = s
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
  }
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
  final _ambiguous = <int>{};

  /// Names a record is also known by, learned from Wikipedia during this
  /// match: the article's title and the redirects used to search.
  final _aka = Map<NormalizedRecord, List<String>>.identity();

  /// The Worker answered that a fallback route is missing or unconfigured
  /// (an older deployment): stop asking it for this match.
  bool _malOff = false;
  bool _wikiOff = false;

  /// MAL search takes up to 8 names per request, as does Wikipedia.
  static const lookupBatch = 8;

  String _query(NormalizedRecord r, String title) => cleanQuery(
    title,
    screen: _isScreen(r.kind) && r.kind != MediaKind.movie,
    preserveParts: !_isScreen(r.kind) || r.kind == MediaKind.movie,
  );

  Future<String?> _malIdentity(NormalizedRecord r) async {
    if (r.malId == null) return null;
    final unspecified = r.kind == null || r.kind == MediaKind.unknown;
    final ids = <String>{
      if (unspecified || r.kind == MediaKind.anime)
        ?await catalog.findByIdentity('mal', '${r.malId}', 'anime'),
      if (unspecified || r.kind!.isReading)
        ?await catalog.findByIdentity('mal', '${r.malId}', 'manga'),
    };
    return ids.length == 1 ? ids.single : null;
  }

  Future<List<MatchedRecord>> match(
    List<NormalizedRecord> records, {
    bool offlineOnly = false,
    void Function(int done, int total)? onProgress,
  }) async {
    _ambiguous.clear();
    _aka.clear();
    _malOff = false;
    _wikiOff = false;
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
        id = await _malIdentity(r);
      }
      if (id != null) {
        final title = await catalog.titleById(id);
        if (title == null ||
            !_kindFits(r.kind, title.kind) ||
            (r.screenOnly && title.kind.isReading) ||
            title.format == 'NOVEL' ||
            title.format == 'MUSIC') {
          id = null;
        } else if (title.adult) {
          out[i] = MatchedRecord(
            r,
            null,
            MatchClass.unresolved,
            included: false,
            adultHidden: true,
          );
          continue;
        }
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
      if (t.adult || t.format == 'NOVEL' || t.format == 'MUSIC') continue;
      for (final n in {t.titleEn, t.titleRomaji, t.titleNative}) {
        if (n != null) byTitle.putIfAbsent(_key(n), () => []).add(t);
      }
    }
    String? localTitle(int index) {
      final r = records[index];
      final unique = <String, Title>{
        for (final name in {r.title, _query(r, r.title), ...r.altTitles})
          for (final t in byTitle[_key(name)] ?? const <Title>[])
            if (_kindFits(r.kind, t.kind) &&
                !(r.screenOnly && t.kind.isReading))
              t.id: t,
      }.values.toList();
      if (unique.isEmpty) return null;
      if (unique.length == 1) return unique.single.id;
      final dated = [
        for (final t in unique)
          if (r.year != null &&
              t.year != null &&
              _yearFits(r.year, t.year) &&
              (r.kind == null || t.kind == r.kind))
            t,
      ];
      if (dated.length == 1) return dated.single.id;
      _ambiguous.add(index);
      return null;
    }

    final remote = <int>[];
    for (final i in pending) {
      final id = localTitle(i);
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
    for (final anime in [true, false]) {
      final withAl = [
        for (final i in remote)
          if (out[i] == null &&
              records[i].anilistId != null &&
              (records[i].kind == null ||
                  records[i].kind == MediaKind.unknown ||
                  (anime
                      ? records[i].kind == MediaKind.anime
                      : records[i].kind!.isReading)))
            i,
      ];
      for (var s = 0; s < withAl.length; s += 50) {
        final chunk = withAl.skip(s).take(50).toList();
        try {
          final found = await gateway.byAniListIds(
            chunk.map((i) => records[i].anilistId!).toSet().toList(),
            anime: anime,
          );
          for (final i in chunk) {
            final item = found
                .where(
                  (d) =>
                      d.provider == 'anilist' &&
                      d.providerId == '${records[i].anilistId}' &&
                      _allowed(records[i], d),
                )
                .firstOrNull;
            if (item == null) continue;
            if (item.json['adult'] == true) {
              out[i] = MatchedRecord(
                records[i],
                null,
                MatchClass.unresolved,
                included: false,
                adultHidden: true,
              );
              continue;
            }
            final ids = await catalog.upsert([item]);
            out[i] = MatchedRecord(
              records[i],
              ids.single,
              MatchClass.exactId,
              included: records[i].confirmed,
            );
            unchecked.remove(i);
          }
        } on CatalogUnavailable {
          unchecked.addAll(chunk.where((i) => out[i] == null));
        }
      }
    }
    final withMal = remote
        .where((i) => out[i] == null && records[i].malId != null)
        .toList();
    for (var s = 0; s < withMal.length; s += 50) {
      final chunk = withMal.skip(s).take(50).toList();
      final anime = [
        for (final i in chunk)
          if (records[i].kind == MediaKind.anime ||
              records[i].kind == null ||
              records[i].kind == MediaKind.unknown)
            records[i].malId!,
      ];
      final manga = [
        for (final i in chunk)
          if ((records[i].kind?.isReading ?? true) ||
              records[i].kind == MediaKind.unknown)
            records[i].malId!,
      ];
      final res = await gateway.match(
        const [],
        malAnime: anime,
        malManga: manga,
      );
      await catalog.upsert(res.mal);
      for (final i in chunk) {
        final id = await _malIdentity(records[i]);
        if (id != null) {
          final title = await catalog.titleById(id);
          if (title == null ||
              title.format == 'NOVEL' ||
              title.format == 'MUSIC') {
            continue;
          }
          if (title.adult) {
            out[i] = MatchedRecord(
              records[i],
              null,
              MatchClass.unresolved,
              included: false,
              adultHidden: true,
            );
            continue;
          }
          out[i] = MatchedRecord(
            records[i],
            id,
            MatchClass.exactId,
            included: records[i].confirmed,
          );
        }
      }
    }

    final byTitle = remote.where((i) => out[i] == null).toList();
    progressed(remote.length - byTitle.length);
    await _titlePass(
      records,
      byTitle,
      (i) => _initialQueries(records[i]),
      out,
      unchecked,
    );
    progressed(byTitle.length);

    // 3b. AniList's search chokes on long or complex titles but finds the
    // show from its first few words, an alternate name from the sheet, or
    // the part before the colon. Try those for what is still unmatched.
    final retry = [
      for (final i in remote)
        if (!_ambiguous.contains(i) &&
            (out[i] == null || out[i]!.matchClass == MatchClass.similar) &&
            !unchecked.contains(i))
          i,
    ];
    await _titlePass(records, retry, _shorterQueries, out, unchecked);

    // 4. Comics still unmatched (or only similar): ask MangaDex for the
    // work's other names and its AniList link.
    final stuck = [
      for (final i in remote)
        if (!_ambiguous.contains(i) &&
            (out[i] == null || out[i]!.matchClass == MatchClass.similar) &&
            !records[i].screenOnly &&
            ((records[i].kind?.isReading ?? true) ||
                records[i].kind == MediaKind.unknown) &&
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

    // The compact batch query returns five hits. The full search used by
    // review can recover a unique exact title beyond that first page.
    for (final i in remote) {
      if (_ambiguous.contains(i) ||
          unchecked.contains(i) ||
          (out[i] != null && out[i]!.matchClass != MatchClass.similar)) {
        continue;
      }
      List<CatalogItemDto> candidates;
      try {
        candidates = await gateway.search(
          _query(records[i], records[i].title),
          kind: records[i].kind,
        );
      } on CatalogUnavailable {
        unchecked.add(i);
        continue;
      }
      final exact = _exact(records[i], candidates);
      if (exact != null) {
        final ids = await catalog.upsert([exact]);
        out[i] = MatchedRecord(
          records[i],
          ids.single,
          MatchClass.suggested,
          included: records[i].confirmed,
        );
      } else if (_exactHits(records[i], candidates).length > 1) {
        _ambiguous.add(i);
      }
    }

    // 5. Still nothing certain: MyAnimeList's own search, then the name
    // Wikipedia uses for the work, asked of AniList and MAL again. Only what
    // all of them miss goes to review.
    bool open(int i) =>
        !_ambiguous.contains(i) &&
        !unchecked.contains(i) &&
        (out[i] == null || out[i]!.matchClass == MatchClass.similar) &&
        _malLists(records[i]).isNotEmpty;
    final malIdx = [
      for (final i in remote)
        if (open(i)) i,
    ];
    await _viaMal(
      records,
      malIdx,
      (i) => [_query(records[i], records[i].title)],
      out,
    );
    // Netflix plays are mostly live action: an encyclopedia article for
    // one would only be searched for as anime.
    final wikiIdx = [
      for (final i in malIdx)
        if (open(i) && !records[i].screenOnly) i,
    ];
    await _viaWikipedia(records, wikiIdx, out);

    // 6. Whatever is left may simply be rated adult, which Cue keeps out of
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
  List<String> _initialQueries(NormalizedRecord r) {
    final names = <String, String>{};
    for (final n in [r.title, ...r.altTitles.take(4)]) {
      final q = _query(r, n);
      names.putIfAbsent(_key(q), () => q);
    }
    return names.values.toList();
  }

  List<String> _shorterQueries(int i, [List<NormalizedRecord>? all]) {
    final r = (all ?? _records)[i];
    final base = _query(r, r.title);
    final tried = _initialQueries(r).map(normTitle).toSet();
    final out = <String>[];
    void add(String q) {
      final c = q.trim();
      if (c.length < 5 || !tried.add(normTitle(c))) return;
      out.add(c);
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
  /// Records in [weak] were searched under a name nobody confirmed (an
  /// encyclopedia's best guess): an exact hit is only offered, unticked.
  Future<void> _titlePass(
    List<NormalizedRecord> records,
    List<int> idx,
    List<String> Function(int) queriesFor,
    List<MatchedRecord?> out,
    Set<int> unchecked, {
    Set<int> weak = const {},
  }) async {
    _records = records;
    final gateway = catalog.gateway;
    final jobs = <(int, String)>[
      for (final i in idx)
        for (final q in queriesFor(i)) (i, q),
    ];
    final candidates = <int, List<CatalogItemDto>>{};
    final failed = <int>{};
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
        failed.addAll(chunk.map((c) => c.$1));
        continue;
      }
      for (var j = 0; j < chunk.length && j < res.results.length; j++) {
        final idx = chunk[j].$1;
        if (res.failed.contains(j)) {
          unchecked.add(idx);
          failed.add(idx);
          continue;
        }
        candidates.putIfAbsent(idx, () => []).addAll(res.results[j]);
      }
    }
    for (final idx in candidates.keys) {
      final r = records[idx];
      if (out[idx] != null && out[idx]!.matchClass != MatchClass.similar) {
        continue;
      }
      final resolved = await catalog.resolveIds(candidates[idx]!);
      final unique = <String, CatalogItemDto>{
        for (final c in candidates[idx]!) resolved[c]!: c,
      }.values.toList();
      final exact = _exact(r, unique);
      if (exact != null &&
          weak.contains(idx) &&
          !_ambiguous.contains(idx) &&
          !failed.contains(idx)) {
        out[idx] ??= _offer(r, exact);
        continue;
      }
      if (exact != null && !_ambiguous.contains(idx) && !failed.contains(idx)) {
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
      if (exact == null && _exactHits(r, unique).length > 1) {
        _ambiguous.add(idx);
      }
      if (out[idx] != null) continue;
      final like = _similar(r, unique);
      if (like != null) out[idx] = _offer(r, like);
    }
  }

  /// Offered, not linked: the catalog row is added only if ticked.
  MatchedRecord _offer(NormalizedRecord r, CatalogItemDto c) => MatchedRecord(
    r,
    c.titleId,
    MatchClass.similar,
    included: false,
    candidate: c,
  );

  /// Which MyAnimeList lists a record may be searched in: `true` for anime,
  /// `false` for comics. Shows, dramas and films have none.
  static List<bool> _malLists(NormalizedRecord r) {
    final k = r.kind;
    final any = k == null || k == MediaKind.unknown;
    return [
      if (any || k == MediaKind.anime) true,
      if (!r.screenOnly && (any || k.isReading)) false,
    ];
  }

  /// An older Worker without the route, or one without a MAL client id.
  static bool _routeMissing(CatalogUnavailable e) =>
      e.code == 'not_found' || e.code == 'not_configured';

  /// MyAnimeList's own search for names AniList did not place. A hit with
  /// one of the record's names is resolved to its AniList entry by MAL id,
  /// so ids stay the same whichever catalog found it; MAL's card is kept
  /// only when AniList has no such entry.
  Future<void> _viaMal(
    List<NormalizedRecord> records,
    List<int> idx,
    List<String> Function(int) queriesFor,
    List<MatchedRecord?> out, {
    Set<int> weak = const {},
  }) async {
    if (idx.isEmpty || _malOff) return;
    final gateway = catalog.gateway;
    final jobs = <(int, MalQuery)>[
      for (final i in idx)
        for (final q in queriesFor(i))
          for (final anime in _malLists(records[i]))
            (i, MalQuery(q, anime: anime)),
    ];
    final found = <int, List<CatalogItemDto>>{};
    for (var s = 0; s < jobs.length; s += lookupBatch) {
      final chunk = jobs.skip(s).take(lookupBatch).toList();
      final List<List<CatalogItemDto>> res;
      try {
        res = await gateway.malSearch([for (final (_, q) in chunk) q]);
      } on CatalogUnavailable catch (e) {
        if (_routeMissing(e)) {
          _malOff = true;
          break;
        }
        continue;
      }
      for (var j = 0; j < chunk.length && j < res.length; j++) {
        found.putIfAbsent(chunk[j].$1, () => []).addAll(res[j]);
      }
    }
    if (found.isEmpty) return;

    // AniList's entries for every MAL hit worth keeping, 50 ids a call.
    final anime = <int>{}, manga = <int>{};
    for (final e in found.entries) {
      final r = records[e.key];
      for (final d in [..._exactHits(r, e.value), ?_similar(r, e.value)]) {
        if (d.idMal case final id?) {
          (d.providerKind == 'manga' ? manga : anime).add(id);
        }
      }
    }
    String keyOf(bool reading, int id) => '${reading ? 'manga' : 'anime'}:$id';
    final lifted = <String, CatalogItemDto>{};
    try {
      for (final (ids, isAnime) in [
        (anime.toList(), true),
        (manga.toList(), false),
      ]) {
        for (var s = 0; s < ids.length; s += 50) {
          final chunk = ids.skip(s).take(50).toList();
          final res = await gateway.match(
            const [],
            malAnime: isAnime ? chunk : const [],
            malManga: isAnime ? const [] : chunk,
          );
          for (final d in res.mal) {
            if (d.idMal case final id?) lifted[keyOf(d.kind.isReading, id)] = d;
          }
        }
      }
    } on CatalogUnavailable {
      // AniList is busy: MAL's own cards stand in.
    }
    CatalogItemDto lift(CatalogItemDto d) => d.idMal == null
        ? d
        : lifted[keyOf(d.providerKind == 'manga', d.idMal!)] ?? d;

    for (final e in found.entries) {
      final i = e.key;
      final r = records[i];
      if (out[i] != null && out[i]!.matchClass != MatchClass.similar) continue;
      final exact = _exact(r, e.value);
      if (exact == null && _exactHits(r, e.value).length > 1) {
        // Two works share the name (an anime and its manga, with no kind
        // to tell them apart): the person picks.
        _ambiguous.add(i);
        continue;
      }
      if (exact != null) {
        final d = lift(exact);
        if (d.json['adult'] == true) {
          out[i] = MatchedRecord(
            r,
            null,
            MatchClass.unresolved,
            included: false,
            adultHidden: true,
          );
          continue;
        }
        if (!_allowed(r, d)) continue;
        if (weak.contains(i)) {
          out[i] ??= _offer(r, d);
          continue;
        }
        final ids = await catalog.upsert([d]);
        out[i] = MatchedRecord(
          r,
          ids.first,
          MatchClass.suggested,
          included: r.confirmed,
        );
        continue;
      }
      if (out[i] != null) continue;
      final like = _similar(r, e.value);
      if (like == null) continue;
      final d = lift(like);
      if (d.json['adult'] != true && _allowed(r, d)) out[i] = _offer(r, d);
    }
  }

  /// Asks Wikipedia what a name refers to. An article that lists one of the
  /// record's names (as its title or a redirect) is confirmed: its title and
  /// a couple of its other names are searched in AniList, then MyAnimeList,
  /// and an exact hit is a normal match. An article found by search alone is
  /// only a guess, so whatever it leads to is offered unticked.
  Future<void> _viaWikipedia(
    List<NormalizedRecord> records,
    List<int> idx,
    List<MatchedRecord?> out,
  ) async {
    if (idx.isEmpty || _wikiOff) return;
    final gateway = catalog.gateway;
    final byKind = <MediaKind?, List<int>>{};
    for (final i in idx) {
      final k = records[i].kind == MediaKind.unknown ? null : records[i].kind;
      byKind.putIfAbsent(k, () => []).add(i);
    }
    final queries = <int, List<String>>{};
    final weak = <int>{};
    outer:
    for (final group in byKind.entries) {
      for (var s = 0; s < group.value.length; s += lookupBatch) {
        final chunk = group.value.skip(s).take(lookupBatch).toList();
        final List<List<WikiNameDto>> res;
        try {
          res = await gateway.canonicalNames([
            for (final i in chunk) _query(records[i], records[i].title),
          ], kind: group.key);
        } on CatalogUnavailable catch (e) {
          if (_routeMissing(e)) {
            _wikiOff = true;
            break outer;
          }
          continue;
        }
        for (var j = 0; j < chunk.length && j < res.length; j++) {
          final i = chunk[j];
          final r = records[i];
          final pages = [
            for (final p in res[j])
              if (p.title.trim().isNotEmpty) p,
          ];
          if (pages.isEmpty) continue;
          final names = _names(r);
          final confirmed = pages
              .where(
                (p) =>
                    [p.title, ...p.names].any((n) => names.contains(_key(n))),
              )
              .firstOrNull;
          final page = confirmed ?? pages.first;
          final tried = {
            for (final q in [
              ..._initialQueries(r),
              ..._shorterQueries(i, records),
            ])
              _key(q),
          };
          final qs = <String>[];
          void add(String n) {
            final q = _query(r, n);
            if (q.length >= 3 && tried.add(_key(q))) qs.add(q);
          }

          add(page.title);
          if (confirmed != null) {
            for (final n in page.names) {
              if (qs.length >= 3) break;
              add(n);
            }
          }
          if (qs.isEmpty) continue;
          queries[i] = qs;
          _aka[r] = [page.title, ...qs];
          if (confirmed == null) weak.add(i);
        }
      }
    }
    if (queries.isEmpty) return;
    final asked = queries.keys.toList();
    // A failed re-query is not "unchecked": AniList already answered once.
    await _titlePass(
      records,
      asked,
      (i) => queries[i]!,
      out,
      <int>{},
      weak: weak,
    );
    final left = [
      for (final i in asked)
        if (!_ambiguous.contains(i) &&
            (out[i] == null || out[i]!.matchClass == MatchClass.similar))
          i,
    ];
    await _viaMal(records, left, (i) => queries[i]!, out, weak: weak);
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
        if (_ambiguous.contains(chunk[j])) continue;
        final r = records[chunk[j]];
        final names = _names(r);
        final matches = <String, CatalogItemDto>{
          for (final c in res[j])
            if (c.item case final item?)
              if (item.json['adult'] != true &&
                  _allowed(r, item) &&
                  c.names.any((n) => names.contains(_key(n))))
                item.titleId: item,
        };
        if (matches.length > 1) _ambiguous.add(chunk[j]);
        if (matches.length == 1) {
          final ids = await catalog.upsert([matches.values.single]);
          out[chunk[j]] = MatchedRecord(
            r,
            ids.first,
            MatchClass.suggested,
            included: r.confirmed,
          );
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
    final wanted = <int, List<AliasCandidateDto>>{};
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
        final matches = <AliasCandidateDto>[
          for (final c in res[j])
            if (_langFits(r.kind, c.lang) &&
                c.names.any((n) => names.contains(_key(n))) &&
                (c.al != null || c.mal != null))
              c,
        ];
        if (matches.isNotEmpty) wanted[chunk[j]] = matches;
      }
    }
    if (wanted.isEmpty) return;
    final found = <int, CatalogItemDto>{};
    final byMal = <int, CatalogItemDto>{};
    try {
      final ids = {for (final c in wanted.values.expand((cs) => cs)) ?c.al}
          .toList();
      for (var s = 0; s < ids.length; s += 50) {
        for (final d in await gateway.byAniListIds(
          ids.skip(s).take(50).toList(),
          anime: false,
        )) {
          found[int.parse(d.providerId)] = d;
        }
      }
      final mals = {
        for (final c in wanted.values.expand((cs) => cs))
          if (c.al == null) ?c.mal,
      }.toList();
      for (var s = 0; s < mals.length; s += 50) {
        final res = await gateway.match(
          const [],
          malManga: mals.skip(s).take(50).toList(),
        );
        for (final d in res.mal) {
          if (d.idMal != null) byMal[d.idMal!] = d;
        }
      }
    } on CatalogUnavailable {
      return;
    }
    for (final e in wanted.entries) {
      final candidates = <CatalogItemDto>[];
      var missing = false;
      for (final c in e.value) {
        final d = c.al != null ? found[c.al] : byMal[c.mal];
        if (d == null) {
          missing = true;
        } else if (d.json['adult'] != true && _allowed(records[e.key], d)) {
          candidates.add(d);
        }
      }
      final resolved = await catalog.resolveIds(candidates);
      final unique = <String, CatalogItemDto>{
        for (final c in candidates) resolved[c]!: c,
      };
      if (unique.length > 1 || missing) _ambiguous.add(e.key);
      if (unique.length != 1 || missing) continue;
      final d = unique.values.single;
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
    for (final n in [r.title, _query(r, r.title), ...r.altTitles, ...?_aka[r]])
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
      _kindFits(r.kind, c.kind) &&
      !(r.screenOnly && c.kind.isReading) &&
      c.json['format'] != 'NOVEL' &&
      c.json['format'] != 'MUSIC';

  /// The first candidate whose title equals one of the record's names.
  /// Several exact titles (two shows called "Big Mouth") are told apart by
  /// year and kind.
  CatalogItemDto? _exact(NormalizedRecord r, List<CatalogItemDto> candidates) {
    var hits = _exactHits(r, candidates);
    if (hits.isEmpty && _isScreen(r.kind) && r.kind != MediaKind.movie) {
      hits = [
        for (final c in candidates)
          if (_allowed(r, c) && _longPrefix(r, c)) c,
      ];
    }
    if (hits.isEmpty) return null;
    if (hits.length == 1) return hits.first;
    final dated = hits.where((c) {
      final year = (c.json['year'] as num?)?.toInt();
      return r.year != null &&
          year != null &&
          _yearFits(r.year, year) &&
          (r.kind == null || c.kind == r.kind);
    }).toList();
    return dated.length == 1 ? dated.single : null;
  }

  List<CatalogItemDto> _exactHits(
    NormalizedRecord r,
    List<CatalogItemDto> candidates,
  ) {
    final names = _names(r);
    return <String, CatalogItemDto>{
      for (final c in candidates)
        if (_allowed(r, c) &&
            _candidateNames(c).any((n) => names.contains(_key(n))))
          c.titleId: c,
    }.values.toList();
  }

  /// The most similar candidate above the threshold, for review.
  CatalogItemDto? _similar(
    NormalizedRecord r,
    List<CatalogItemDto> candidates,
  ) {
    final queries = [r.title, cleanQuery(r.title), ...r.altTitles, ...?_aka[r]];
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
