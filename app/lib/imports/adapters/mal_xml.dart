import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../../domain/models/library.dart';
import '../../domain/models/title.dart';
import '../records.dart';

/// MyAnimeList list export (anime or manga XML). DOCTYPE and ENTITY
/// declarations are refused before parsing.
class MalXmlAdapter {
  static const id = 'mal_xml';
  static const version = '1';

  ParsedImport parse(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    if (RegExp(r'<!DOCTYPE|<!ENTITY', caseSensitive: false).hasMatch(text)) {
      throw const ImportRejected(
        'This XML declares a DOCTYPE or ENTITY, which Cue refuses for safety.',
      );
    }
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(text);
    } on XmlException {
      throw const ImportRejected('This MyAnimeList file is not valid XML.');
    }
    final root = doc.rootElement;
    final records = <NormalizedRecord>[];
    var skipped = 0;
    for (final e in root.childElements) {
      final anime = e.name.local == 'anime';
      final manga = e.name.local == 'manga';
      if (!anime && !manga) continue;
      if (records.length >= ImportLimits.maxRows) {
        throw const ImportRejected(
          'This list has too many entries to read safely.',
        );
      }
      String v(String name) => cleanField(e.getElement(name)?.innerText);
      final malId = int.tryParse(
        v(anime ? 'series_animedb_id' : 'manga_mangadb_id'),
      );
      final title = v(anime ? 'series_title' : 'manga_title');
      if (title.isEmpty) {
        skipped++;
        continue;
      }
      final status = v('my_status');
      final score = int.tryParse(v('my_score')) ?? 0;
      final times =
          int.tryParse(v(anime ? 'my_times_watched' : 'my_times_read')) ?? 0;
      final rewatching = v(anime ? 'my_rewatching' : 'my_rereading') == '1';
      final progress = double.tryParse(
        v(anime ? 'my_watched_episodes' : 'my_read_chapters'),
      );
      final total = double.tryParse(
        v(anime ? 'series_episodes' : 'manga_chapters'),
      );
      final finished = _date(v('my_finish_date'));
      final state = _state(status, anime: anime);
      records.add(
        NormalizedRecord(
          sourceEntryKey:
              'mal:${anime ? 'anime' : 'manga'}:${malId ?? title.toLowerCase()}',
          title: title,
          kind: anime ? MediaKind.anime : null,
          malId: malId,
          state: state,
          statusOriginal: status,
          rating: _rating(score, times, rewatching, state),
          // 0 means unscored, not a zero rating.
          ratingOriginal: score > 0 ? '$score' : null,
          ratingScale: score > 0 ? '10' : null,
          progressUnit: progress != null && progress > 0
              ? (anime ? 'episode' : 'chapter')
              : null,
          progressValue: progress != null && progress > 0 ? progress : null,
          latestKnown: total != null && total > 0 ? total : null,
          actualWatchedAt: finished,
          activityDate: finished ?? _date(v('my_start_date')),
        ),
      );
    }
    return ParsedImport(
      sourceType: id,
      adapterVersion: version,
      records: records,
      skipped: skipped,
    );
  }

  static LibraryState _state(String s, {required bool anime}) =>
      switch (s.toLowerCase()) {
        'completed' => LibraryState.completed,
        'watching' => LibraryState.watching,
        'reading' => LibraryState.reading,
        'on-hold' || 'on hold' => LibraryState.onHold,
        'dropped' => LibraryState.dropped,
        'plan to watch' || 'plan to read' => LibraryState.planned,
        _ => LibraryState.none,
      };

  /// For ranking only. Rewatch counts beat scores; unscored stays unrated.
  static Rating? _rating(
    int score,
    int times,
    bool rewatching,
    LibraryState state,
  ) {
    if (times > 0 || rewatching) return Rating.rewatched;
    if (state == LibraryState.dropped && score == 0) return Rating.dropped;
    if (score == 0) return null;
    if (score >= 9) return Rating.favourite;
    if (score >= 7) return Rating.once;
    if (score >= 5) return Rating.okay;
    return Rating.disliked;
  }

  /// MAL writes 0000-00-00 for unknown dates; partial dates stay unknown.
  static DateTime? _date(String s) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (m == null) return null;
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    if (y == 0 || mo == 0 || d == 0) return null;
    return DateTime.utc(y, mo, d);
  }
}
