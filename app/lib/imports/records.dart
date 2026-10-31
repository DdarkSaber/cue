import '../domain/models/library.dart';
import '../domain/models/title.dart';

/// Thrown for files Cue will not read. Messages are safe to show and never
/// contain file content.
class ImportRejected implements Exception {
  const ImportRejected(this.message);
  final String message;
  @override
  String toString() => 'ImportRejected($message)';
}

/// Bounds for untrusted files.
abstract final class ImportLimits {
  static const maxFileBytes = 20 * 1024 * 1024;
  static const maxExpandedBytes = 100 * 1024 * 1024;
  static const maxRows = 100000;
  static const maxRatio = 100;
  static const maxField = 500;
}

/// One entry from any source, normalised. Unknown stays null.
class NormalizedRecord {
  const NormalizedRecord({
    required this.sourceEntryKey,
    required this.title,
    this.altTitles = const [],
    this.kind,
    this.malId,
    this.anilistId,
    this.year,
    this.state = LibraryState.none,
    this.statusOriginal,
    this.rating,
    this.ratingOriginal,
    this.ratingScale,
    this.rewatchMood,
    this.progressUnit,
    this.progressValue,
    this.latestKnown,
    this.activityDate,
    this.actualWatchedAt,
    this.plays,
    this.note,
    this.cueId,
  });

  /// Cue's own stable title id, present in Cue backups.
  final String? cueId;

  /// Stable per source entry, so re-importing the same file is idempotent.
  final String sourceEntryKey;
  final String title;
  final List<String> altTitles;
  final MediaKind? kind;
  final int? malId;
  final int? anilistId;
  final int? year;
  final LibraryState state;
  final String? statusOriginal;

  /// Derived for ranking only; the original is kept alongside.
  final Rating? rating;
  final String? ratingOriginal;
  final String? ratingScale;
  final RewatchMood? rewatchMood;
  final String? progressUnit;
  final double? progressValue;
  final double? latestKnown;

  /// Last activity seen in the source (e.g. a Netflix play date).
  final DateTime? activityDate;

  /// When the person actually finished it, only if the source says so.
  final DateTime? actualWatchedAt;
  final int? plays;
  final String? note;

  NormalizedRecord copyWith({MediaKind? kind}) => NormalizedRecord(
    sourceEntryKey: sourceEntryKey,
    title: title,
    altTitles: altTitles,
    kind: kind ?? this.kind,
    malId: malId,
    anilistId: anilistId,
    year: year,
    state: state,
    statusOriginal: statusOriginal,
    rating: rating,
    ratingOriginal: ratingOriginal,
    ratingScale: ratingScale,
    rewatchMood: rewatchMood,
    progressUnit: progressUnit,
    progressValue: progressValue,
    latestKnown: latestKnown,
    activityDate: activityDate,
    actualWatchedAt: actualWatchedAt,
    plays: plays,
    note: note,
    cueId: cueId,
  );
}

/// The parts of a Cue backup beyond library rows.
class BackupExtras {
  const BackupExtras({
    this.shortlist = const [],
    this.notInterested = const [],
    this.notNow = const {},
    this.catalog = const [],
    this.settings = const {},
    this.showAdult,
    this.region,
    this.displayName,
  });

  final List<String> shortlist;
  final List<String> notInterested;

  /// Title id to the date it becomes eligible again.
  final Map<String, DateTime> notNow;

  /// Public catalog rows so a restore works offline.
  final List<Map<String, dynamic>> catalog;
  final Map<String, String> settings;
  final bool? showAdult;
  final String? region;
  final String? displayName;
}

/// What an adapter produced, before matching.
class ParsedImport {
  const ParsedImport({
    required this.sourceType,
    required this.adapterVersion,
    required this.records,
    this.warnings = const [],
    this.skipped = 0,
    this.dateRange,
    this.needsDateOrder = false,
    this.extras,
  });

  final BackupExtras? extras;

  final String sourceType;
  final String adapterVersion;
  final List<NormalizedRecord> records;
  final List<String> warnings;

  /// Rows deliberately not imported (e.g. "not watched" in a Cue backup).
  final int skipped;

  /// First and last activity date (Netflix).
  final (DateTime, DateTime)? dateRange;

  /// Dates were ambiguous (e.g. 03/04/24); the preview asks which order.
  final bool needsDateOrder;
}

/// Trims, strips control characters and caps length. Values are text only.
String cleanField(String? raw) {
  if (raw == null) return '';
  final s = raw
      .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'), '')
      .trim();
  return s.length > ImportLimits.maxField
      ? s.substring(0, ImportLimits.maxField)
      : s;
}
