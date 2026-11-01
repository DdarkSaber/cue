import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/models/title.dart';
import '../domain/title_names.dart';
import 'catalog_gateway.dart';
import 'db/database.dart';

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

  /// Pulls the next discover page for a kind (and optional mood).
  /// Returns how many items arrived; 0 when exhausted or unavailable.
  Future<int> fetchNext(MediaKind kind, {String? mood}) async {
    if (unavailableKinds.contains(kind)) return 0;
    final next = await _nextPage(kind, mood);
    if (next == 0 || next > 50) return 0;
    final moodKey = mood ?? '';
    final CatalogPageDto page;
    try {
      page = await gateway.discover(kind, mood: mood, page: next);
    } on CatalogUnavailable catch (e) {
      if (e.code == 'not_configured') unavailableKinds.add(kind);
      rethrow;
    }
    await upsert(page.items);
    await db
        .into(db.catalogPages)
        .insertOnConflictUpdate(
          CatalogPagesCompanion.insert(
            mediaKind: kind.name,
            mood: Value(moodKey),
            page: next,
            hasNext: page.hasNext,
            fetchedAt: _now(),
          ),
        );
    return page.items.length;
  }

  Future<CatalogPageState> pageState(MediaKind kind, {String? mood}) async {
    if (unavailableKinds.contains(kind)) return CatalogPageState.unavailable;
    final next = await _nextPage(kind, mood);
    if (next == 0) return CatalogPageState.exhausted;
    return next > 50 ? CatalogPageState.limited : CatalogPageState.more;
  }

  Future<int> _nextPage(MediaKind kind, String? mood) async {
    final moodKey = mood ?? '';
    final pages =
        await (db.select(db.catalogPages)..where(
              (p) => p.mediaKind.equals(kind.name) & p.mood.equals(moodKey),
            ))
            .get();
    final stale = _now().subtract(const Duration(days: 7));
    final fresh = pages.where((p) => p.fetchedAt.isAfter(stale)).toList()
      ..sort((a, b) => a.page.compareTo(b.page));
    if (fresh.isNotEmpty && !fresh.last.hasNext) return 0;
    return fresh.isEmpty ? 1 : fresh.last.page + 1;
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
