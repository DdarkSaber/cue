import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/models/title.dart';
import 'db/database.dart';

/// Writes the active library as a Cue backup (schema v1). Tokens, raw
/// import files and anything not personal are never included.
class BackupService {
  BackupService(this.db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final CueDatabase db;
  final DateTime Function() _now;

  Future<String> export(String profileId) async {
    final profile = await (db.select(
      db.profiles,
    )..where((p) => p.id.equals(profileId))).getSingle();
    final settings =
        await (db.select(db.profileSettings)..where(
              (s) =>
                  s.profileId.equals(profileId) & s.key.isNotValue('_active'),
            ))
            .get();
    final ut = await (db.select(
      db.userTitles,
    )..where((u) => u.profileId.equals(profileId))).get();
    final sl = await (db.select(
      db.shortlist,
    )..where((s) => s.profileId.equals(profileId))).get();
    final ex =
        await (db.select(db.exclusions)..where(
              (x) => x.profileId.equals(profileId) & x.active.equals(true),
            ))
            .get();
    final de =
        await (db.select(db.deferrals)..where(
              (d) =>
                  d.profileId.equals(profileId) &
                  d.eligibleAfter.isBiggerThanValue(_now()),
            ))
            .get();
    final ids = {
      ...ut.map((u) => u.titleId),
      ...sl.map((s) => s.titleId),
      ...ex.map((x) => x.titleId),
      ...de.map((d) => d.titleId),
    }.toList();
    final titles = {
      for (final r in await (db.select(
        db.catalogTitles,
      )..where((t) => t.id.isIn(ids))).get())
        r.id: r,
    };
    final identities = <String, Map<String, String>>{};
    for (final i in await (db.select(
      db.catalogIdentities,
    )..where((i) => i.titleId.isIn(ids))).get()) {
      identities.putIfAbsent(i.titleId, () => {})[i.provider] = i.providerId;
    }

    // Dates are calendar days: write the UTC day so no time zone shifts it.
    String? day(DateTime? d) => d?.toUtc().toIso8601String().substring(0, 10);
    Map<String, Object?> titleRef(String id) {
      final t = titles[id];
      return {
        'cue_id': id,
        'title': t == null ? id : Title.fromRow(t).displayTitle,
        'media': t?.mediaKind ?? 'unknown',
      };
    }

    final doc = {
      'cue': 'backup',
      'schema_version': 1,
      'exported_at': day(_now()),
      'profile': {
        if (profile.displayName != null) 'display_name': profile.displayName,
        'region': profile.region,
        'show_adult': profile.showAdult,
      },
      'settings': {for (final s in settings) s.key: s.value},
      'items': [
        for (final u in ut)
          {
            ...titleRef(u.titleId),
            if (titles[u.titleId]?.titleRomaji != null)
              'alt_title': titles[u.titleId]!.titleRomaji,
            'status': u.state,
            if (u.rating != null) 'rating': u.rating,
            if (u.rewatchMood != null) 'rewatch_mood': u.rewatchMood,
            if (titles[u.titleId]?.year != null)
              'year': titles[u.titleId]!.year,
            if (u.progressValue != null || u.latestKnown != null)
              'progress': {
                'unit': u.progressUnit,
                'read_to': u.progressValue,
                'latest_known': u.latestKnown,
              },
            if (u.actualWatchedAt != null) 'watched_at': day(u.actualWatchedAt),
            if (u.note != null) 'note': u.note,
            if (identities[u.titleId] != null)
              'ids': {
                for (final e in identities[u.titleId]!.entries)
                  if (e.key == 'mal' || e.key == 'anilist')
                    e.key: int.tryParse(e.value),
              },
          },
      ],
      'shortlist': [for (final s in sl) titleRef(s.titleId)],
      'not_interested': [for (final x in ex) titleRef(x.titleId)],
      'not_now': [
        for (final d in de)
          {...titleRef(d.titleId), 'until': day(d.eligibleAfter)},
      ],
      // Public catalog rows for the titles above, so a restore works offline.
      'catalog': [
        for (final t in titles.values)
          {
            'id': t.id,
            'kind': t.mediaKind,
            'titleEn': t.titleEn,
            'titleRomaji': t.titleRomaji,
            'titleNative': t.titleNative,
            'year': t.year,
            'country': t.country,
            'format': t.format,
            'status': t.status,
            'episodes': t.episodes,
            'chapters': t.chapters,
            'genres': jsonDecode(t.genresJson),
            'tags': jsonDecode(t.tagsJson),
            'score': t.score,
            'posterUrl': t.posterUrl,
            'franchiseKey': t.franchiseId,
            'adult': t.adult,
            'identities': identities[t.id] ?? const {},
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(doc);
  }
}
