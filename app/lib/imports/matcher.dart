import '../data/catalog_gateway.dart';
import '../data/catalog_repository.dart';
import '../domain/models/title.dart';
import 'records.dart';

/// How a record was tied to a catalog title. Numeric similarity is never
/// presented as a probability.
enum MatchClass { exactId, confirmed, suggested, unresolved }

class MatchedRecord {
  MatchedRecord(
    this.record,
    this.titleId,
    this.matchClass, {
    this.included = true,
  });

  final NormalizedRecord record;
  final String? titleId;
  final MatchClass matchClass;

  /// Unticked in the preview (e.g. a Netflix show someone else watched).
  bool included;

  bool get resolved => titleId != null;
}

/// Lower-case, punctuation-free form used for exact title comparison.
String normTitle(String s) => s
    .toLowerCase()
    .replaceAll('’', "'")
    .replaceAll(RegExp(r'[^a-z0-9぀-ヿ一-鿿가-힯]+'), ' ')
    .trim();

bool _kindFits(MediaKind? wanted, MediaKind got) {
  if (wanted == null || wanted == MediaKind.unknown) return true;
  if (wanted == got) return true;
  // Reading kinds are often mislabelled across sources; keep them together.
  return wanted.isReading && got.isReading;
}

/// Resolution order: provider id, then exact title (+ kind, + year when
/// both known), else the review queue. Title-only matches are "suggested":
/// the person confirms them in the preview.
class ImportMatcher {
  ImportMatcher(this.catalog);
  final CatalogRepository catalog;

  static const batchSize = 15;

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
      for (final name in [r.title, ...r.altTitles]) {
        for (final t in byTitle[normTitle(name)] ?? const <Title>[]) {
          if (_kindFits(r.kind, t.kind) && _yearFits(r.year, t.year)) {
            return t.id;
          }
        }
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

    // 3. The Worker, in batches: MAL ids first, then titles.
    var done = records.length - remote.length;
    onProgress?.call(done, records.length);
    if (!offlineOnly && remote.isNotEmpty) {
      try {
        await _remote(records, remote, out, (n) {
          done += n;
          onProgress?.call(done, records.length);
        });
      } on CatalogUnavailable {
        // Offline mid-way: whatever is left stays in the review queue.
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
            ),
    ];
  }

  Future<void> _remote(
    List<NormalizedRecord> records,
    List<int> remote,
    List<MatchedRecord?> out,
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
      final res = await gateway.match([
        for (final i in chunk) MatchQuery(records[i].title, records[i].kind),
      ]);
      for (var j = 0; j < chunk.length && j < res.results.length; j++) {
        final r = records[chunk[j]];
        final pick = _pick(r, res.results[j]);
        if (pick == null) continue;
        final ids = await catalog.upsert([pick]);
        out[chunk[j]] = MatchedRecord(r, ids.first, MatchClass.suggested);
      }
      progressed(chunk.length);
    }
  }

  /// The first candidate whose title equals one of the record's names.
  CatalogItemDto? _pick(NormalizedRecord r, List<CatalogItemDto> candidates) {
    final names = {
      for (final n in [r.title, ...r.altTitles]) normTitle(n),
    };
    for (final c in candidates) {
      if (!_kindFits(r.kind, c.kind)) continue;
      final j = c.json;
      final year = (j['year'] as num?)?.toInt();
      if (!_yearFits(r.year, year)) continue;
      for (final k in ['titleEn', 'titleRomaji', 'titleNative']) {
        final v = j[k] as String?;
        if (v != null && names.contains(normTitle(v))) return c;
      }
    }
    return null;
  }

  static bool _yearFits(int? a, int? b) =>
      a == null || b == null || (a - b).abs() <= 1;
}
