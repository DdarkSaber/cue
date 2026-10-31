import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/models/title.dart';
import 'catalog_gateway.dart';
import 'db/database.dart';

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
      final resolved = await _resolveIds(items);
      final existingRows = await (db.select(
        db.catalogTitles,
      )..where((t) => t.id.isIn(resolved.values.toSet().toList()))).get();
      final existingById = {for (final r in existingRows) r.id: r};
      for (final dto in items) {
        final id = resolved[dto]!;
        ids.add(id);
        final j = dto.json;
        final existing = existingById[id];
        if (existing != null && existing.detailed && !detailed) {
          continue;
        }
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

  Future<Map<CatalogItemDto, String>> _resolveIds(
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
    return {
      for (final d in items)
        d:
            byKey[key(d.provider, d.providerId, d.providerKind ?? '')] ??
            (d.idMal == null
                ? null
                : byKey[key(
                    'mal',
                    '${d.idMal}',
                    d.kind.isReading ? 'manga' : 'anime',
                  )]) ??
            d.titleId,
    };
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
              'tmdb' => id.split(':')[1],
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
    const hosts = {'s4.anilist.co', 'image.tmdb.org', 'static.tvmaze.com'};
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
    final next = fresh.isEmpty ? 1 : fresh.last.page + 1;
    if (next > 50) return 0;
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
