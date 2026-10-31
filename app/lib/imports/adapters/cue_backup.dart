import 'dart:convert';
import 'dart:typed_data';

import '../../domain/models/library.dart';
import '../../domain/models/title.dart';
import '../records.dart';

/// Cue's own interchange format (schema v1). The documented schema only;
/// arbitrary JSON is refused.
class CueBackupAdapter {
  static const id = 'cue_backup';
  static const version = '1';

  ParsedImport parse(Uint8List bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    } on FormatException {
      throw const ImportRejected('This backup is not valid JSON.');
    }
    if (json is! Map || json['cue'] != 'backup') {
      throw const ImportRejected('This is not a Cue backup.');
    }
    final schema = json['schema_version'];
    if (schema is! int || schema > 1) {
      throw const ImportRejected(
        'This backup was made by a newer Cue. Update the app to import it.',
      );
    }
    final items = json['items'];
    if (items is! List) throw const ImportRejected('This backup has no items.');
    if (items.length > ImportLimits.maxRows) {
      throw const ImportRejected(
        'This backup has too many items to read safely.',
      );
    }
    final records = <NormalizedRecord>[];
    var skipped = 0;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if (it is! Map) {
        skipped++;
        continue;
      }
      String? s(String k) {
        final v = it[k];
        if (v == null) return null;
        final c = cleanField(v.toString());
        return c.isEmpty ? null : c;
      }

      final title = s('title');
      final status = s('status');
      // "not_watched" rows describe things not seen: nothing to import.
      if (title == null || status == 'not_watched') {
        skipped++;
        continue;
      }
      final progress = it['progress'] is Map ? it['progress'] as Map : const {};
      final ids = it['ids'] is Map ? it['ids'] as Map : const {};
      final media = MediaKind.parse(s('media'));
      records.add(
        NormalizedRecord(
          sourceEntryKey:
              'cue:${s('id') ?? '${media.name}:${title.toLowerCase()}'}',
          title: title,
          altTitles: [
            ?s('alt_title'),
            if (it['entries'] is List)
              for (final e in (it['entries'] as List).take(8))
                cleanField(e.toString()),
          ],
          kind: media == MediaKind.unknown ? null : media,
          malId: _int(ids['mal']),
          anilistId: _int(ids['anilist']),
          year: _int(it['year']),
          state: _state(status),
          statusOriginal: status,
          rating: Rating.parse(s('rating')),
          rewatchMood: RewatchMood.parse(s('rewatch_mood')),
          progressUnit: s('unit') ?? (progress['unit'] as String?),
          progressValue: _num(progress['read_to']),
          latestKnown: _num(progress['latest_known']),
          activityDate: _dateOf(s('last_activity')),
          actualWatchedAt: _dateOf(s('watched_at')),
          plays: _int(it['netflix_plays']),
          note: s('note'),
          cueId: _cueId(it['cue_id']),
        ),
      );
    }
    return ParsedImport(
      sourceType: id,
      adapterVersion: version,
      records: records,
      skipped: skipped,
      extras: _extras(json),
    );
  }

  /// Only ids in Cue's own shape ("anilist:1", "tmdb:tv:9", "tvmaze:3").
  static String? _cueId(Object? v) {
    if (v is! String) return null;
    return RegExp(
          r'^(anilist|tvmaze):\d{1,12}$|^tmdb:(tv|movie):\d{1,12}$|^cinemeta:(movie|series):tt\d{1,12}$',
        ).hasMatch(v)
        ? v
        : null;
  }

  static List<String> _refs(Object? list) => [
    if (list is List)
      for (final r in list.take(ImportLimits.maxRows))
        if (r is Map && _cueId(r['cue_id']) != null) _cueId(r['cue_id'])!,
  ];

  static const _allowedSettings = {
    'reduceMotion',
    'haptics',
    'swipeMap',
    'defaultKinds',
    'includeRewatches',
    'inviteDismissed',
  };

  static BackupExtras _extras(Map<dynamic, dynamic> json) {
    final notNow = <String, DateTime>{};
    if (json['not_now'] is List) {
      for (final r in json['not_now'] as List) {
        if (r is! Map) continue;
        final id = _cueId(r['cue_id']);
        final until = _dateOf(r['until'] as String?);
        if (id != null && until != null) notNow[id] = until;
      }
    }
    final settings = <String, String>{};
    if (json['settings'] is Map) {
      for (final e in (json['settings'] as Map).entries) {
        if (_allowedSettings.contains(e.key) && e.value is String) {
          settings[e.key as String] = cleanField(e.value as String);
        }
      }
    }
    final profile = json['profile'] is Map ? json['profile'] as Map : const {};
    final region = profile['region'];
    return BackupExtras(
      shortlist: _refs(json['shortlist']),
      notInterested: _refs(json['not_interested']),
      notNow: notNow,
      catalog: [
        if (json['catalog'] is List)
          for (final c in (json['catalog'] as List).take(ImportLimits.maxRows))
            if (c is Map && _cueId(c['id']) != null)
              Map<String, dynamic>.from(c),
      ],
      settings: settings,
      showAdult: profile['show_adult'] is bool
          ? profile['show_adult'] as bool
          : null,
      region: region is String && RegExp(r'^[A-Z]{2}$').hasMatch(region)
          ? region
          : null,
      displayName: profile['display_name'] is String
          ? cleanField(profile['display_name'] as String)
          : null,
    );
  }

  static LibraryState _state(String? s) => switch (s) {
    'completed' => LibraryState.completed,
    'seen' => LibraryState.seen,
    'watching' => LibraryState.watching,
    'reading' => LibraryState.reading,
    'caught_up' => LibraryState.caughtUp,
    'partial' || 'activity_only' => LibraryState.partial,
    'on_hold' => LibraryState.onHold,
    'planned' => LibraryState.planned,
    'dropped' => LibraryState.dropped,
    _ => LibraryState.none,
  };

  static int? _int(Object? v) => v is int
      ? v
      : (v is String ? int.tryParse(v) : (v is num ? v.toInt() : null));
  static double? _num(Object? v) =>
      v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
  static DateTime? _dateOf(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    return m == null
        ? null
        : DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
}
