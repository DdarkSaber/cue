import '../../domain/models/library.dart';
import '../../domain/models/title.dart';
import '../records.dart';

/// Normalises list entries from MAL (through the Worker) and AniList.
/// Same rules as files: unscored is unrated, unknown dates stay unknown.
ParsedImport parseListEntries(
  String provider,
  List<Map<String, dynamic>> entries,
) {
  final records = <NormalizedRecord>[];
  var skipped = 0;
  for (final e in entries.take(ImportLimits.maxRows)) {
    final title = cleanField(e['title'] as String?);
    if (title.isEmpty) {
      skipped++;
      continue;
    }
    final status = (e['status'] as String? ?? '').toLowerCase();
    final state = _state(status);
    final score = (e['score'] as num?)?.toInt();
    final repeat = (e['repeat'] as num?)?.toInt() ?? 0;
    final kind = MediaKind.parse(e['kind'] as String?);
    final completed = _date(e['completedAt'] as String?);
    final anilistId = (e['anilistId'] as num?)?.toInt();
    final malId = (e['malId'] as num?)?.toInt();
    records.add(
      NormalizedRecord(
        sourceEntryKey: anilistId != null
            ? 'anilist:$anilistId'
            : malId != null
            ? 'mal:${kind == MediaKind.anime ? 'anime' : 'manga'}:$malId'
            : 'title:${title.toLowerCase()}',
        title: title,
        kind: kind == MediaKind.unknown ? null : kind,
        anilistId: anilistId,
        malId: malId,
        state: state,
        statusOriginal: status,
        rating: _rating(score, repeat, state),
        ratingOriginal: score?.toString(),
        ratingScale: e['scoreScale'] as String?,
        progressUnit: (e['progress'] as num?) == null
            ? null
            : (kind == MediaKind.anime ? 'episode' : 'chapter'),
        progressValue: (e['progress'] as num?)?.toDouble(),
        actualWatchedAt: completed,
        activityDate: completed,
      ),
    );
  }
  return ParsedImport(
    sourceType: '${provider}_api',
    adapterVersion: '1',
    records: records,
    skipped: skipped,
  );
}

LibraryState _state(String s) => switch (s) {
  'completed' => LibraryState.completed,
  'current' || 'watching' => LibraryState.watching,
  'reading' => LibraryState.reading,
  'repeating' => LibraryState.watching,
  'paused' || 'on_hold' => LibraryState.onHold,
  'dropped' => LibraryState.dropped,
  'planning' || 'plan_to_watch' || 'plan_to_read' => LibraryState.planned,
  _ => LibraryState.none,
};

Rating? _rating(int? score, int repeat, LibraryState state) {
  if (repeat > 0) return Rating.rewatched;
  if (score == null || score == 0) {
    return state == LibraryState.dropped ? Rating.dropped : null;
  }
  if (score >= 9) return Rating.favourite;
  if (score >= 7) return Rating.once;
  if (score >= 5) return Rating.okay;
  return Rating.disliked;
}

DateTime? _date(String? s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s ?? '');
  return m == null
      ? null
      : DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}
