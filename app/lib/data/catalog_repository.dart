import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/models/title.dart';
import '../domain/title_names.dart';
import 'anilist_client.dart' show AniListClient;
import 'catalog_gateway.dart';
import 'db/database.dart';
import 'request_priority.dart';

/// Where a discover route stands. [limited] is kept for callers that still
/// handle it, but no page ceiling exists any more: routes are [more] until
/// every provider order reported its final page.
enum CatalogPageState { more, exhausted, limited, unavailable }

class CatalogSearchResult {
  const CatalogSearchResult(this.items, {this.failureCode});
  final List<CatalogItemDto> items;
  final String? failureCode;

  String? get warning => switch (failureCode) {
    null => null,
    'rate_limited' =>
      'A catalog is busy. Results may be incomplete; try again shortly.',
    'offline' => 'A catalog could not be reached. Showing available matches; try again when connected.',
    _ => 'A catalog search failed. Results may be incomplete; try again.',
  };
}

/// Local catalog cache plus the Worker behind it. Everything the deck shows
/// comes from the local tables, so the deck works offline after first run.
/// A cap on provider requests shared by everything one refill cycle (or one
/// filter set's background continuations) does. AniList allows about 30
/// requests a minute, so an unbounded fan-out only queues behind the pacer.
/// The first request of each route is claimed before any route digs deeper,
/// so every route gets a look before one overlapping route spends the rest,
/// and the budget closes early once [freshTarget] unseen titles arrived.
class RequestBudget {
  RequestBudget({this.limit = 12, this.freshTarget = 100});

  /// Most discover/recommendation requests the budget allows.
  final int limit;

  /// Unseen titles after which no further request is worth making.
  final int freshTarget;

  int used = 0;
  int fresh = 0;

  bool get spent => used >= limit || fresh >= freshTarget;

  /// Claims one request; false when the budget is spent.
  bool take() {
    if (spent) return false;
    used++;
    return true;
  }
}

class CatalogRepository {
  CatalogRepository(this.db, this.gateway, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final CueDatabase db;
  final CatalogGateway gateway;
  final DateTime Function() _now;

  /// Kinds the Worker said it cannot serve (e.g. no TMDB key). Session only.
  final Set<MediaKind> unavailableKinds = {};

  /// Upserts Worker items. Detailed rows are never downgraded by list rows.
  Future<List<String>> upsert(
    List<CatalogItemDto> items, {
    bool detailed = false,
  }) async {
    final now = _now();
    final ids = <String>[];
    await db.transaction(() async {
      // One query for every identity and existing row, not one per item.
      final resolved = await resolveIds(items);
      final existingRows = await (db.select(
        db.catalogTitles,
      )..where((t) => t.id.isIn(resolved.values.toSet().toList()))).get();
      final existingById = {for (final r in existingRows) r.id: r};
      for (final dto in items) {
        final id = resolved[dto]!;
        ids.add(id);
        final j = dto.json;
        final existing = existingById[id];
        if (existing == null || !existing.detailed || detailed) {
          await db
              .into(db.catalogTitles)
              .insertOnConflictUpdate(
                CatalogTitlesCompanion.insert(
                  id: id,
                  mediaKind: dto.kind.name,
                  titleEn: Value(j['titleEn'] as String?),
                  titleRomaji: Value(j['titleRomaji'] as String?),
                  titleNative: Value(j['titleNative'] as String?),
                  year: Value((j['year'] as num?)?.toInt()),
                  country: Value(j['country'] as String?),
                  format: Value(j['format'] as String?),
                  status: Value((j['status'] as String?) ?? 'unknown'),
                  episodes: Value((j['episodes'] as num?)?.toInt()),
                  chapters: Value((j['chapters'] as num?)?.toInt()),
                  seasonsJson: Value(jsonEncode(j['seasons'] ?? const [])),
                  genresJson: Value(jsonEncode(j['genres'] ?? const [])),
                  tagsJson: Value(jsonEncode(j['tags'] ?? const [])),
                  score: Value((j['score'] as num?)?.toInt()),
                  posterUrl: Value(j['posterUrl'] as String?),
                  backdropUrl: Value(j['backdropUrl'] as String?),
                  synopsis: Value(j['synopsis'] as String?),
                  franchiseId: Value(j['franchiseKey'] as String?),
                  adult: Value(j['adult'] == true),
                  detailed: Value(detailed || (existing?.detailed ?? false)),
                  updatedAt: now,
                ),
              );
        }
        await _identity(id, dto.provider, dto.providerId, dto.providerKind);
        if (dto.idMal != null) {
          await _identity(
            id,
            'mal',
            '${dto.idMal}',
            dto.kind.isReading ? 'manga' : 'anime',
          );
        }
      }
    });
    return ids;
  }

  /// Resolve a batch without writing it, including shared MAL identities.
  Future<Map<CatalogItemDto, String>> resolveIds(
    List<CatalogItemDto> items,
  ) async {
    final providerIds = items.map((d) => d.providerId).toSet().toList();
    final malIds = [
      for (final d in items)
        if (d.idMal != null) '${d.idMal}',
    ];
    final known =
        await (db.select(db.catalogIdentities)..where(
              (i) =>
                  i.providerId.isIn(providerIds) |
                  (i.provider.equals('mal') & i.providerId.isIn(malIds)),
            ))
            .get();
    String key(String p, String id, String k) => '$p|$id|$k';
    final byKey = {
      for (final i in known)
        key(i.provider, i.providerId, i.providerKind): i.titleId,
    };
    final resolved = <CatalogItemDto, String>{};
    for (final d in items) {
      final id =
          byKey[key(d.provider, d.providerId, d.providerKind ?? '')] ??
          (d.idMal == null
              ? null
              : byKey[key(
                  'mal',
                  '${d.idMal}',
                  d.kind.isReading ? 'manga' : 'anime',
                )]) ??
          d.titleId;
      resolved[d] = id;
      byKey[key(d.provider, d.providerId, d.providerKind ?? '')] = id;
      if (d.idMal != null) {
        byKey[key('mal', '${d.idMal}', d.kind.isReading ? 'manga' : 'anime')] =
            id;
      }
    }
    return resolved;
  }

  /// A title already known under another identity keeps its id (e.g. an
  /// import created it from a MAL id before AniList was seen).
  Future<String> resolveId(CatalogItemDto dto) async {
    final known = await findByIdentity(
      dto.provider,
      dto.providerId,
      dto.providerKind ?? '',
    );
    if (known != null) return known;
    if (dto.idMal != null) {
      final viaMal = await findByIdentity(
        'mal',
        '${dto.idMal}',
        dto.kind.isReading ? 'manga' : 'anime',
      );
      if (viaMal != null) return viaMal;
    }
    return dto.titleId;
  }

  Future<void> _identity(
    String titleId,
    String provider,
    String providerId,
    String? providerKind,
  ) => db
      .into(db.catalogIdentities)
      .insert(
        CatalogIdentitiesCompanion.insert(
          titleId: titleId,
          provider: provider,
          providerId: providerId,
          providerKind: Value(providerKind ?? ''),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  /// Inserts catalog rows from a Cue backup when they are not cached yet.
  /// Ids are Cue's own stable ids, so they are used as given.
  Future<void> restoreSnapshot(List<Map<String, dynamic>> rows) async {
    final now = _now();
    await db.transaction(() async {
      for (final j in rows) {
        final id = j['id'] as String;
        if (await titleById(id) != null) continue;
        final kind = MediaKind.parse(j['kind'] as String?);
        await db
            .into(db.catalogTitles)
            .insert(
              CatalogTitlesCompanion.insert(
                id: id,
                mediaKind: kind.name,
                titleEn: Value(j['titleEn'] as String?),
                titleRomaji: Value(j['titleRomaji'] as String?),
                titleNative: Value(j['titleNative'] as String?),
                year: Value((j['year'] as num?)?.toInt()),
                country: Value(j['country'] as String?),
                format: Value(j['format'] as String?),
                status: Value((j['status'] as String?) ?? 'unknown'),
                episodes: Value((j['episodes'] as num?)?.toInt()),
                chapters: Value((j['chapters'] as num?)?.toInt()),
                genresJson: Value(jsonEncode(j['genres'] ?? const [])),
                tagsJson: Value(jsonEncode(j['tags'] ?? const [])),
                score: Value((j['score'] as num?)?.toInt()),
                posterUrl: Value(_allowedPoster(j['posterUrl'] as String?)),
                franchiseId: Value(j['franchiseKey'] as String?),
                adult: Value(j['adult'] == true),
                updatedAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        final ids = j['identities'];
        if (ids is Map) {
          for (final e in ids.entries) {
            final provider = '${e.key}';
            await _identity(id, provider, '${e.value}', switch (provider) {
              'mal' => kind.isReading ? 'manga' : 'anime',
              'tmdb' || 'cinemeta' => id.split(':')[1],
              _ => '',
            });
          }
        }
      }
    });
  }

  /// Posters only from the official catalog hosts.
  static String? _allowedPoster(String? url) {
    final u = url == null ? null : Uri.tryParse(url);
    const hosts = {
      's4.anilist.co',
      'image.tmdb.org',
      'static.tvmaze.com',
      'images.metahub.space',
      'cdn.mangaupdates.com',
    };
    return u != null && u.scheme == 'https' && hosts.contains(u.host)
        ? url
        : null;
  }

  Future<String?> findByIdentity(
    String provider,
    String providerId, [
    String providerKind = '',
  ]) async {
    final row =
        await (db.select(db.catalogIdentities)
              ..where(
                (i) =>
                    i.provider.equals(provider) &
                    i.providerId.equals(providerId) &
                    i.providerKind.equals(providerKind),
              )
              ..limit(1))
            .getSingleOrNull();
    return row?.titleId;
  }

  Future<List<Title>> titlesByIds(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return const [];
    final rows = await (db.select(
      db.catalogTitles,
    )..where((t) => t.id.isIn(list))).get();
    return rows.map(Title.fromRow).toList();
  }

  Future<Title?> titleById(String id) async {
    final row = await (db.select(
      db.catalogTitles,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : Title.fromRow(row);
  }

  /// Every cached title of the given kinds.
  Future<List<Title>> pool(Iterable<MediaKind> kinds) async {
    final names = kinds.map((k) => k.name).toList();
    final rows = await (db.select(
      db.catalogTitles,
    )..where((t) => t.mediaKind.isIn(names))).get();
    return rows.map(Title.fromRow).toList();
  }

  /// Titles one deal can rank. Past this many candidates, extra rows add
  /// deal time but almost never change the ten cards chosen.
  static const candidateLimit = 8000;

  /// Cached titles that could be dealt, with the hard exclusions applied in
  /// SQL so a 20k-title cache costs a deal no more than a fresh one: disabled
  /// kinds, novels and music, hidden adult titles, [excludeIds] (library,
  /// shortlist, not interested, set aside) and [excludeFranchises].
  ///
  /// Unless [limit] is null, at most that many rows load: the best scored and
  /// the most recently cached share it. Callers narrowing with filters pass
  /// null, since a small filtered set must not be cut by unrelated titles.
  Future<List<Title>> candidatePool(
    Iterable<MediaKind> kinds, {
    Set<String> excludeIds = const {},
    Set<String> excludeFranchises = const {},
    bool showAdult = false,
    int? limit = candidateLimit,
  }) async {
    final names = kinds.map((k) => k.name).toList();
    // SQLite caps bound variables; a longer exclusion list is applied after.
    final inSql = excludeIds.length <= 20000;
    Expression<bool> where($CatalogTitlesTable t) {
      Expression<bool> w =
          t.mediaKind.isIn(names) &
          (t.format.isNull() | t.format.isNotIn(const ['NOVEL', 'MUSIC']));
      if (!showAdult) w = w & t.adult.equals(false);
      if (inSql && excludeIds.isNotEmpty) {
        w = w & t.id.isNotIn(excludeIds.toList());
      }
      if (excludeFranchises.isNotEmpty) {
        w =
            w &
            (t.franchiseId.isNull() |
                t.franchiseId.isNotIn(excludeFranchises.toList()));
      }
      return w;
    }

    Future<List<CatalogTitle>> load(
      List<OrderClauseGenerator<$CatalogTitlesTable>> order,
      int n,
    ) =>
        (db.select(db.catalogTitles)
              ..where(where)
              ..orderBy(order)
              ..limit(n))
            .get();

    List<CatalogTitle> rows;
    final matching = limit == null
        ? 0
        : (await (db.selectOnly(db.catalogTitles)
                    ..addColumns([db.catalogTitles.id.count()])
                    ..where(where(db.catalogTitles)))
                  .getSingle())
              .read(db.catalogTitles.id.count())!;
    // Within the cap nothing is left out, and storage order is kept.
    if (limit == null || matching <= limit) {
      rows =
          await (db.select(db.catalogTitles)
                ..where(where)
                // Storage order, whichever index the query planner picks.
                ..orderBy([
                  (_) => OrderingTerm(
                    expression: const CustomExpression<int>('rowid'),
                  ),
                ]))
              .get();
    } else {
      final byScore = await load([
        (t) => OrderingTerm.desc(t.score),
        (t) => OrderingTerm.desc(t.updatedAt),
      ], (limit * 5) ~/ 8);
      final byRecent = await load([
        (t) => OrderingTerm.desc(t.updatedAt),
      ], limit - (limit * 5) ~/ 8);
      final seen = <String>{};
      rows = [
        for (final r in [...byScore, ...byRecent])
          if (seen.add(r.id)) r,
      ];
    }
    return [
      for (final r in rows)
        if (inSql || !excludeIds.contains(r.id)) Title.fromRow(r),
    ];
  }

  /// Whether any title of these kinds is cached, however it is filtered.
  Future<bool> hasCached(Iterable<MediaKind> kinds) async {
    final c = db.catalogTitles.id.count();
    final q = db.selectOnly(db.catalogTitles)
      ..addColumns([c])
      ..where(db.catalogTitles.mediaKind.isIn(kinds.map((k) => k.name)));
    return ((await q.getSingle()).read(c) ?? 0) > 0;
  }

  /// The same cached catalog that supplies the deck remains searchable offline.
  Future<CatalogSearchResult> search(String query) async {
    final q = query.trim();
    final key = normTitle(q);
    if (key.isEmpty) return const CatalogSearchResult([]);
    final cached = await pool(MediaKind.values);
    final local = cached
        .where(
          (t) =>
              !t.adult &&
              t.format != 'NOVEL' &&
              t.format != 'MUSIC' &&
              [
                t.titleEn,
                t.titleRomaji,
                t.titleNative,
              ].any((n) => n != null && normTitle(n).contains(key)),
        )
        .toList();
    bool exact(Iterable<String> names) => names.any((n) => normTitle(n) == key);
    local.sort((a, b) {
      bool matches(Title t) =>
          exact([?t.titleEn, ?t.titleRomaji, ?t.titleNative]);
      return (matches(b) ? 1 : 0).compareTo(matches(a) ? 1 : 0);
    });
    final identities = await (db.select(
      db.catalogIdentities,
    )..where((i) => i.titleId.isIn(local.take(20).map((t) => t.id)))).get();
    final byId = <String, CatalogItemDto>{};
    for (final t in local.take(20)) {
      final identity = identities
          .where((i) => i.titleId == t.id && i.provider != 'mal')
          .firstOrNull;
      final parts = t.id.split(':');
      if (identity == null && parts.length < 2) continue;
      byId[t.id] = CatalogItemDto({
        'provider': identity?.provider ?? parts.first,
        'providerId': identity?.providerId ?? parts.last,
        'providerKind':
            identity?.providerKind ?? (parts.length == 3 ? parts[1] : null),
        'kind': t.kind.name,
        'titleEn': t.titleEn,
        'titleRomaji': t.titleRomaji,
        'titleNative': t.titleNative,
        'year': t.year,
        'country': t.country,
        'format': t.format,
        'status': t.status,
        'episodes': t.episodes,
        'chapters': t.chapters,
        'seasons': t.seasons.map((s) => s.toJson()).toList(),
        'genres': t.genres,
        'tags': t.tags,
        'score': t.score,
        'posterUrl': t.posterUrl,
        'backdropUrl': t.backdropUrl,
        'synopsis': t.synopsis,
        'franchiseKey': t.franchiseId,
        'adult': t.adult,
      });
    }
    String? failure;
    List<CatalogItemDto> remote;
    try {
      remote = await gateway.search(q);
    } on CatalogSearchIncomplete catch (e) {
      remote = e.items;
      failure = e.code;
    } on CatalogUnavailable catch (e) {
      remote = const [];
      failure = e.code;
    }
    final resolved = await resolveIds(remote);
    for (final item in remote) {
      if (item.json['adult'] != true &&
          item.json['format'] != 'NOVEL' &&
          item.json['format'] != 'MUSIC') {
        byId.putIfAbsent(resolved[item]!, () => item);
      }
    }
    final results = byId.values.toList()
      ..sort(
        (a, b) => (exact(b.names) ? 1 : 0).compareTo(exact(a.names) ? 1 : 0),
      );
    return CatalogSearchResult(results, failureCode: failure);
  }

  Future<int> countFor(MediaKind kind) async {
    final c = db.catalogTitles.id.count();
    final q = db.selectOnly(db.catalogTitles)
      ..addColumns([c])
      ..where(db.catalogTitles.mediaKind.equals(kind.name));
    return (await q.getSingle()).read(c) ?? 0;
  }

  /// Requests one [fetchNext] call may make for a single route while pages
  /// keep coming back mostly already known.
  static const maxPagesPerFetch = 3;

  /// New titles one [fetchNext] call is happy with before it stops digging.
  static const freshTarget = 10;

  /// Cursor key for a route: the mood plus the sort, for non-default sorts.
  /// The default order keeps the bare mood key, so existing cursors carry on.
  static String _routeKey(String? mood, String? sort, List<String?> sorts) =>
      sort == null || sort == sorts.first
      ? (mood ?? '')
      : '${mood ?? ''}~$sort';

  /// Pulls the next discover pages for a kind (and optional mood).
  ///
  /// Each provider order (AniList: popularity, trending, score, favourites,
  /// newest) keeps its own cursor and they take turns, so a big watched
  /// library that covers the popular pages does not starve supply. When a
  /// page is mostly titles already cached (library, earlier swipes), the
  /// call digs on, up to [maxPagesPerFetch] requests, until [freshTarget]
  /// new titles arrive. There is no page ceiling: only a provider's final
  /// page in every order proves exhaustion.
  ///
  /// Returns how many items arrived; 0 when exhausted or unavailable.
  Future<int> fetchNext(
    MediaKind kind, {
    String? mood,
    RequestBudget? budget,
  }) async {
    if (unavailableKinds.contains(kind)) return 0;
    final sorts = gateway.discoverSorts(kind);
    var arrived = 0;
    var fresh = 0;
    for (var request = 0; request < maxPagesPerFetch; request++) {
      final next = await _nextRoute(kind, mood, sorts);
      if (next == null) break;
      if (budget != null && !budget.take()) break;
      final CatalogPageDto page;
      try {
        page = await gateway.discover(
          kind,
          mood: mood,
          page: next.page,
          sort: next.sort,
        );
      } on CatalogUnavailable catch (e) {
        if (e.code == 'not_configured') unavailableKinds.add(kind);
        // What already arrived counts; the failure shows on the next call.
        if (request == 0) rethrow;
        break;
      }
      // A catalog route never really ends on an empty first page; that is
      // a provider fault (AniList once answered null filters that way), so
      // it is not remembered as the end of the catalog.
      if (next.page == 1 && page.items.isEmpty && !page.hasNext) break;
      final known = await _knownIds(page.items);
      final newHere = page.items.length - known;
      await upsert(page.items);
      await db
          .into(db.catalogPages)
          .insertOnConflictUpdate(
            CatalogPagesCompanion.insert(
              mediaKind: kind.name,
              mood: Value(next.key),
              page: next.page,
              hasNext: page.hasNext,
              fetchedAt: _now(),
            ),
          );
      arrived += page.items.length;
      fresh += newHere;
      budget?.fresh += newHere;
      // Dig on only when overlap with the cache, not a short page, is why
      // this page added little.
      if (fresh >= freshTarget || known <= newHere) break;
    }
    return arrived;
  }

  /// How many of these items are already cached under some identity.
  Future<int> _knownIds(List<CatalogItemDto> items) async {
    if (items.isEmpty) return 0;
    final resolved = await resolveIds(items);
    final ids = resolved.values.toSet().toList();
    final rows =
        await (db.selectOnly(db.catalogTitles)
              ..addColumns([db.catalogTitles.id])
              ..where(db.catalogTitles.id.isIn(ids)))
            .get();
    return rows.length;
  }

  Future<CatalogPageState> pageState(MediaKind kind, {String? mood}) async {
    if (unavailableKinds.contains(kind)) return CatalogPageState.unavailable;
    final next = await _nextRoute(kind, mood, gateway.discoverSorts(kind));
    return next == null ? CatalogPageState.exhausted : CatalogPageState.more;
  }

  /// The next page to pull for a kind and mood: the least-advanced order
  /// that still has pages, the default order first on ties. Null when every
  /// order reported its final page within the last seven days.
  Future<({String? sort, String key, int page})?> _nextRoute(
    MediaKind kind,
    String? mood,
    List<String?> sorts,
  ) async {
    await _forgetFalseEnds();
    final keys = {for (final s in sorts) s: _routeKey(mood, s, sorts)};
    final rows =
        await (db.select(db.catalogPages)..where(
              (p) =>
                  p.mediaKind.equals(kind.name) &
                  p.mood.isIn(keys.values.toSet().toList()),
            ))
            .get();
    final stale = _now().subtract(const Duration(days: 7));
    ({String? sort, String key, int page})? best;
    for (final sort in sorts) {
      final key = keys[sort]!;
      final fresh =
          rows
              .where((p) => p.mood == key && p.fetchedAt.isAfter(stale))
              .toList()
            ..sort((a, b) => a.page.compareTo(b.page));
      if (fresh.isNotEmpty && !fresh.last.hasNext) continue;
      final page = fresh.isEmpty ? 1 : fresh.last.page + 1;
      if (best == null || page < best.page) {
        best = (sort: sort, key: key, page: page);
      }
    }
    return best;
  }

  bool _falseEndsForgotten = false;

  /// Earlier builds recorded AniList's empty answers to null filters as the
  /// final page of a route, which hid anime (and comics) for a week. A real
  /// AniList route never ends on page 1, so those rows are dropped once.
  Future<void> _forgetFalseEnds() async {
    if (_falseEndsForgotten) return;
    _falseEndsForgotten = true;
    final names = [for (final k in AniListClient.kinds) k.name];
    await (db.delete(db.catalogPages)..where(
          (p) =>
              p.mediaKind.isIn(names) &
              p.page.equals(1) &
              p.hasNext.equals(false),
        ))
        .go();
  }

  /// Marker rows in [CatalogPages] remember when a seed was last asked.
  static const _seedMarker = '_seed';

  /// Seeds asked about per call; AniList takes four per request.
  static const maxSeedsPerFetch = 4;

  /// Taste-seeded retrieval: asks providers what people who liked each
  /// seed also liked, caches those titles and remembers the edges, so the
  /// ranker can boost them and say "Because you liked ...". Seeds asked in
  /// the last seven days are skipped. Only provider ids leave the device.
  ///
  /// [seedIds] are catalog ids, strongest first. Returns edges stored.
  Future<int> fetchSeeded(List<String> seedIds, {RequestBudget? budget}) async {
    if (seedIds.isEmpty) return 0;
    final stale = _now().subtract(const Duration(days: 7));
    final asked =
        await (db.select(db.catalogPages)..where(
              (p) =>
                  p.mediaKind.equals(_seedMarker) &
                  p.mood.isIn(seedIds) &
                  p.fetchedAt.isBiggerThanValue(stale),
            ))
            .get();
    final skip = {for (final p in asked) p.mood};
    final identities = await (db.select(
      db.catalogIdentities,
    )..where((i) => i.titleId.isIn(seedIds))).get();
    final refs = <String, SeedRef>{};
    for (final id in seedIds) {
      if (skip.contains(id) || refs.length >= maxSeedsPerFetch) continue;
      final mine = identities.where((i) => i.titleId == id);
      final ref =
          mine
              .where((i) => i.provider == 'anilist')
              .map((i) => SeedRef('anilist', i.providerId))
              .firstOrNull ??
          mine
              .where((i) => i.provider == 'tmdb')
              .map((i) => SeedRef('tmdb', i.providerId, i.providerKind))
              .firstOrNull;
      if (ref != null) refs[id] = ref;
    }
    if (refs.isEmpty) return 0;
    if (budget != null && !budget.take()) return 0;
    final results = await withRequestPriority(
      RequestPriority.seed,
      () => gateway.recommendations(refs.values.toList()),
    );
    var stored = 0;
    final now = _now();
    final seeds = refs.keys.toList();
    for (var i = 0; i < seeds.length && i < results.length; i++) {
      final items = [
        for (final d in results[i])
          if (d.json['adult'] != true &&
              d.json['format'] != 'NOVEL' &&
              d.json['format'] != 'MUSIC')
            d,
      ];
      final ids = await upsert(items);
      await db.transaction(() async {
        for (var r = 0; r < ids.length; r++) {
          if (ids[r] == seeds[i]) continue;
          await db
              .into(db.catalogRecommendations)
              .insertOnConflictUpdate(
                CatalogRecommendationsCompanion.insert(
                  seedId: seeds[i],
                  titleId: ids[r],
                  rank: r,
                  fetchedAt: now,
                ),
              );
          stored++;
        }
        await db
            .into(db.catalogPages)
            .insertOnConflictUpdate(
              CatalogPagesCompanion.insert(
                mediaKind: _seedMarker,
                mood: Value(seeds[i]),
                page: 1,
                hasNext: false,
                // An empty answer may be a half-failed batch (the hybrid
                // gateway hides one provider failing), so ask again after
                // a day rather than waiting out the whole week.
                fetchedAt: items.isEmpty
                    ? now.subtract(const Duration(days: 6))
                    : now,
              ),
            );
      });
    }
    return stored;
  }

  /// Marker row remembering when [pruneRecommendations] last ran.
  static const _maintenanceMarker = '_maintenance';
  static const recommendationKeep = Duration(days: 90);
  static const maintenanceEvery = Duration(days: 1);

  /// Drops recommendation edges that can no longer matter: those of seeds
  /// that are no longer a current top seed and were fetched over 90 days ago.
  /// Cheap, and at most once a day unless [force]. Returns rows removed.
  Future<int> pruneRecommendations(
    Iterable<String> currentSeeds, {
    bool force = false,
  }) async {
    final now = _now();
    final marker =
        await (db.select(db.catalogPages)..where(
              (p) =>
                  p.mediaKind.equals(_maintenanceMarker) &
                  p.mood.equals('recommendations'),
            ))
            .getSingleOrNull();
    if (!force &&
        marker != null &&
        now.difference(marker.fetchedAt) < maintenanceEvery) {
      return 0;
    }
    final cutoff = now.subtract(recommendationKeep);
    final seeds = currentSeeds.toList();
    final removed =
        await (db.delete(db.catalogRecommendations)..where(
              (r) =>
                  r.fetchedAt.isSmallerThanValue(cutoff) &
                  r.seedId.isNotIn(seeds),
            ))
            .go();
    await (db.delete(db.catalogPages)..where(
          (p) =>
              p.mediaKind.equals(_seedMarker) &
              p.fetchedAt.isSmallerThanValue(cutoff) &
              p.mood.isNotIn(seeds),
        ))
        .go();
    await db
        .into(db.catalogPages)
        .insertOnConflictUpdate(
          CatalogPagesCompanion.insert(
            mediaKind: _maintenanceMarker,
            mood: const Value('recommendations'),
            page: 1,
            hasNext: false,
            fetchedAt: now,
          ),
        );
    return removed;
  }

  /// Full title (seasons, keywords) for the details sheet. Falls back to the
  /// cached row when offline.
  Future<Title?> detailed(String titleId) async {
    final cached = await titleById(titleId);
    if (cached != null && cached.detailed) return cached;
    final ids = await (db.select(
      db.catalogIdentities,
    )..where((i) => i.titleId.equals(titleId))).get();
    final id = ids
        .where((i) => i.provider != 'mal')
        .cast<CatalogIdentity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (id == null) return cached;
    try {
      final dto = await gateway.title(
        id.provider,
        id.providerId,
        type: id.providerKind.isEmpty ? null : id.providerKind,
      );
      if (dto == null) return cached;
      await upsert([dto], detailed: true);
      return await titleById(titleId);
    } on CatalogUnavailable {
      return cached;
    }
  }

  /// Where to watch, cached a week. TMDB titles only; null when unknown.
  Future<WatchProvidersDto?> watchProviders(
    String titleId,
    String region,
  ) async {
    final cached =
        await (db.select(db.watchProviders)..where(
              (w) => w.titleId.equals(titleId) & w.region.equals(region),
            ))
            .getSingleOrNull();
    if (cached != null &&
        cached.fetchedAt.isAfter(_now().subtract(const Duration(days: 7)))) {
      return WatchProvidersDto.fromJson(
        jsonDecode(cached.providersJson) as Map<String, dynamic>,
      );
    }
    final tmdb =
        await (db.select(db.catalogIdentities)
              ..where(
                (i) => i.titleId.equals(titleId) & i.provider.equals('tmdb'),
              )
              ..limit(1))
            .getSingleOrNull();
    if (tmdb == null) return null;
    try {
      final p = await gateway.providers(
        tmdb.providerId,
        tmdb.providerKind.isEmpty ? 'tv' : tmdb.providerKind,
        region,
      );
      await db
          .into(db.watchProviders)
          .insertOnConflictUpdate(
            WatchProvidersCompanion.insert(
              titleId: titleId,
              region: region,
              providersJson: jsonEncode(p.toJson()),
              fetchedAt: _now(),
            ),
          );
      return p;
    } on CatalogUnavailable {
      return cached == null
          ? null
          : WatchProvidersDto.fromJson(
              jsonDecode(cached.providersJson) as Map<String, dynamic>,
            );
    }
  }
}
