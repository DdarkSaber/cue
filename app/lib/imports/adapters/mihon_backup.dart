import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';

import '../../domain/models/library.dart';
import '../../domain/models/title.dart';
import '../records.dart';

/// Mihon / Tachiyomi backup (gzip + protobuf). Reads only an allowlist:
/// title, read chapter markers and MAL/AniList tracker ids. Preferences,
/// sources, extension repos and tracker credentials are skipped unread.
///
/// Field numbers follow Mihon's Backup.proto: Backup.backupManga = 1;
/// BackupManga.title = 3, genre = 7, chapters = 16, tracking = 18,
/// history = 104; BackupHistory.lastRead = 2 (epoch milliseconds);
/// BackupChapter.read = 4, chapterNumber = 9;
/// BackupTracking.syncId = 1, mediaIdInt = 3, lastChapterRead = 6,
/// totalChapters = 7, mediaId = 100.
class MihonBackupAdapter {
  static const id = 'mihon_backup';
  static const version = '1';

  static const _syncMal = 1;
  static const _syncAniList = 2;

  /// A cheap check: the first field is a length-delimited field 1.
  static bool looksLikeBackup(Uint8List bytes) =>
      bytes.isNotEmpty && bytes[0] == 0x0A;

  ParsedImport parse(Uint8List bytes) {
    final records = <NormalizedRecord>[];
    final reader = CodedBufferReader(
      bytes,
      sizeLimit: ImportLimits.maxExpandedBytes,
    );
    try {
      while (!reader.isAtEnd()) {
        final tag = reader.readTag();
        if (getTagFieldNumber(tag) == 1 &&
            getTagWireType(tag) == WIRETYPE_LENGTH_DELIMITED) {
          final r = _manga(reader.readBytes(), records.length);
          if (r != null) records.add(r);
          if (records.length > ImportLimits.maxRows) {
            throw const ImportRejected(
              'This backup has too many entries to read safely.',
            );
          }
        } else {
          reader.skipField(tag);
        }
      }
    } on ImportRejected {
      rethrow;
    } on Object {
      throw const ImportRejected(
        'This Mihon backup could not be read. Make a fresh backup and try again.',
      );
    }
    return ParsedImport(
      sourceType: id,
      adapterVersion: version,
      records: records,
      warnings: const [
        'Only titles, read chapters and tracker ids were read. Settings, sources and tracker logins were skipped.',
      ],
    );
  }

  NormalizedRecord? _manga(List<int> data, int index) {
    final r = CodedBufferReader(data);
    String? title;
    var readCount = 0;
    double? highestRead;
    int? malId, anilistId;
    double? trackerRead, trackerTotal;
    final genres = <String>[];
    int? lastReadMs;
    while (!r.isAtEnd()) {
      final tag = r.readTag();
      switch (getTagFieldNumber(tag)) {
        case 3:
          title = cleanField(r.readString());
        case 7:
          if (genres.length < 40) genres.add(r.readString().toLowerCase());
        case 104:
          final at = _historyLastRead(r.readBytes());
          if (at != null && (lastReadMs == null || at > lastReadMs)) {
            lastReadMs = at;
          }
        case 16:
          final (read, number) = _chapter(r.readBytes());
          if (read) {
            readCount++;
            if (number != null && number >= 0) {
              highestRead = highestRead == null || number > highestRead
                  ? number
                  : highestRead;
            }
          }
        case 18:
          final t = _tracking(r.readBytes());
          if (t.syncId == _syncMal && t.mediaId != null) malId = t.mediaId;
          if (t.syncId == _syncAniList && t.mediaId != null) {
            anilistId = t.mediaId;
          }
          trackerRead ??= t.lastRead;
          trackerTotal ??= t.total;
        default:
          r.skipField(tag);
      }
    }
    if (title == null || title.isEmpty) return null;
    // A read chapter 183 does not prove 1-182 were read: progress is the
    // tracker's figure when present, otherwise the highest read marker.
    final progress = trackerRead != null && trackerRead > 0
        ? trackerRead
        : highestRead;
    return NormalizedRecord(
      sourceEntryKey: malId != null
          ? 'mal:$malId'
          : anilistId != null
          ? 'anilist:$anilistId'
          : 'title:${title.toLowerCase()}',
      title: title,
      kind: _kind(genres),
      malId: malId,
      anilistId: anilistId,
      state: readCount == 0 ? LibraryState.planned : LibraryState.reading,
      // When a chapter was last opened: a recency hint for taste.
      activityDate: lastReadMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastReadMs, isUtc: true),
      progressUnit: progress == null ? null : 'chapter',
      progressValue: progress,
      latestKnown: trackerTotal != null && trackerTotal > 0
          ? trackerTotal
          : null,
    );
  }

  /// The source's own genre labels often name the format.
  static MediaKind? _kind(List<String> genres) {
    bool has(String g) => genres.any((x) => x.trim() == g);
    if (has('manhwa') || has('webtoon')) return MediaKind.manhwa;
    if (has('manhua')) return MediaKind.manhua;
    if (has('manga')) return MediaKind.manga;
    return null;
  }

  /// BackupHistory.lastRead, ignoring zero and far-future stamps.
  int? _historyLastRead(List<int> data) {
    final r = CodedBufferReader(data);
    int? at;
    while (!r.isAtEnd()) {
      final tag = r.readTag();
      if (getTagFieldNumber(tag) == 2) {
        at = r.readInt64().toInt();
      } else {
        r.skipField(tag);
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    return at != null && at > 0 && at <= now + 86400000 ? at : null;
  }

  (bool, double?) _chapter(List<int> data) {
    final r = CodedBufferReader(data);
    var read = false;
    double? number;
    while (!r.isAtEnd()) {
      final tag = r.readTag();
      switch (getTagFieldNumber(tag)) {
        case 4:
          read = r.readBool();
        case 9:
          number = r.readFloat();
        default:
          r.skipField(tag);
      }
    }
    return (read, number);
  }

  ({int? syncId, int? mediaId, double? lastRead, double? total}) _tracking(
    List<int> data,
  ) {
    final r = CodedBufferReader(data);
    int? syncId, mediaId;
    double? lastRead, total;
    while (!r.isAtEnd()) {
      final tag = r.readTag();
      switch (getTagFieldNumber(tag)) {
        case 1:
          syncId = r.readInt32();
        case 3:
          mediaId ??= r.readInt32();
        case 100:
          mediaId = r.readInt64().toInt();
        case 6:
          lastRead = r.readFloat();
        case 7:
          total = r.readInt32().toDouble();
        default:
          // Tracking URLs, titles, scores, dates: not needed, not kept.
          r.skipField(tag);
      }
    }
    return (
      syncId: syncId,
      mediaId: mediaId != null && mediaId > 0 ? mediaId : null,
      lastRead: lastRead,
      total: total,
    );
  }
}
