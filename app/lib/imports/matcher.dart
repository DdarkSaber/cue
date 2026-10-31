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
  if (p.length < 2 || q.length < 2) return 0;
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
  return 2 * shared / ((p.length - 1) + (q.length - 1));
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
        out[i] = MatchedRecord(r, id, MatchClass.exactId);
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
        out[i] = MatchedRecord(records[i], id, MatchClass.suggested);
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
    for (var s = 0; s < byTitle.length; s += batchSize) {
      final chunk = byTitle.skip(s).take(batchSize).toList();
      final MatchResponse res;
      try {
        res = await gateway.match([
          for (final i in chunk)
            MatchQuery(
              cleanQuery(
                records[i].title,
                screen:
                    _isScreen(records[i].kind) &&
                    records[i].kind != MediaKind.movie,
              ),
              records[i].kind,
            ),
        ]);
      } on CatalogUnavailable {
        unchecked.addAll(chunk);
        progressed(chunk.length);
        continue;
      }
      for (var j = 0; j < chunk.length && j < res.results.length; j++) {
        final idx = chunk[j];
        if (res.failed.contains(j)) {
          unchecked.add(idx);
          continue;
        }
        final r = records[idx];
        final exact = _exact(r, res.results[j]);
        if (exact != null) {
          final ids = await catalog.upsert([exact]);
          out[idx] = MatchedRecord(r, ids.first, MatchClass.suggested);
          continue;
        }
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
      progressed(chunk.length);
    }
  }

  Set<String> _names(NormalizedRecord r) => {
    for (final n in [
      r.title,
      cleanQuery(r.title),
      cleanQuery(r.title, screen: true),
      ...r.altTitles,
    ])
      normTitle(n),
  };

  Iterable<String> _candidateNames(CatalogItemDto c) sync* {
    for (final k in ['titleEn', 'titleRomaji', 'titleNative']) {
      final v = c.json[k] as String?;
      if (v != null) yield v;
    }
  }

  /// The first candidate whose title equals one of the record's names.
  /// Several exact titles (two shows called "Big Mouth") are told apart by
  /// year and kind.
  CatalogItemDto? _exact(NormalizedRecord r, List<CatalogItemDto> candidates) {
    final names = _names(r);
    final hits = [
      for (final c in candidates)
        if (_kindFits(r.kind, c.kind) &&
            _candidateNames(c).any((n) => names.contains(normTitle(n))))
          c,
    ];
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
      if (!_kindFits(r.kind, c.kind)) continue;
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
