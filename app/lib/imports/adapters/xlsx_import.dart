import 'dart:typed_data';

import '../../domain/models/library.dart';
import '../../domain/models/title.dart';
import '../records.dart';
import 'xlsx_sheets.dart';

/// A spreadsheet of titles, one worksheet per kind of thing. A sheet is read
/// when it has a header row with a "Title" column; the other columns are
/// recognised by name. Worksheets named like "Not watched" are skipped.
class XlsxImportAdapter {
  static const id = 'xlsx';
  static const version = '1';

  ParsedImport parse(Uint8List bytes) {
    final sheets = readXlsx(bytes);
    final records = <NormalizedRecord>[];
    final warnings = <String>[];
    var skipped = 0;
    for (final sheet in sheets) {
      final lower = sheet.name.toLowerCase();
      final notWatched =
          lower.contains('not watched') || lower.contains('unwatched');
      final head = _headerRow(sheet.rows);
      if (head == null) continue;
      if (notWatched) {
        skipped += sheet.rows.length - head.index - 1;
        warnings.add(
          '"${sheet.name}" lists things not watched, so it was skipped.',
        );
        continue;
      }
      final cols = _Columns(sheet.rows[head.index]);
      for (var i = head.index + 1; i < sheet.rows.length; i++) {
        final r = sheet.rows[i];
        String? at(int? c) =>
            c == null || c >= r.length || r[c].isEmpty ? null : r[c];
        final title = at(cols.title);
        if (title == null) {
          skipped++;
          continue;
        }
        final status = at(cols.status);
        final state = _state(status, lower);
        final rating = _rating(at(cols.rating));
        final read = double.tryParse(at(cols.readTo) ?? '');
        final latest = double.tryParse(at(cols.latest) ?? '');
        final kind = _kind(sheet.name, at(cols.kind));
        records.add(
          NormalizedRecord(
            sourceEntryKey:
                'xlsx:${kind?.name ?? 'any'}:${title.toLowerCase()}',
            title: title,
            altTitles: [?at(cols.alt)],
            kind: kind,
            year: int.tryParse(at(cols.year) ?? ''),
            state: state,
            statusOriginal: status,
            rating: rating,
            ratingOriginal: at(cols.rating),
            rewatchMood: RewatchMood.parse(at(cols.mood)),
            progressUnit: read == null ? null : 'chapter',
            progressValue: read,
            latestKnown: latest,
            // Month-level activity only; the real watch date stays unknown.
            activityDate: _month(at(cols.last)),
            plays: int.tryParse(at(cols.plays) ?? ''),
            note: at(cols.notes),
          ),
        );
      }
    }
    if (records.isEmpty) {
      throw const ImportRejected(
        'Cue found no sheet with a "Title" column in this spreadsheet.',
      );
    }
    return ParsedImport(
      sourceType: id,
      adapterVersion: version,
      records: records,
      skipped: skipped,
      warnings: warnings,
    );
  }

  /// First row in the top ten that has a cell reading "title".
  ({int index})? _headerRow(List<List<String>> rows) {
    for (var i = 0; i < rows.length && i < 10; i++) {
      if (rows[i].any((c) => c.trim().toLowerCase() == 'title')) {
        return (index: i);
      }
    }
    return null;
  }

  /// What the sheet name says the rows are, refined by a "Type" column.
  static MediaKind? _kind(String sheet, String? column) {
    final c = (column ?? '').toLowerCase();
    if (c.contains('k-drama') || c.contains('korean')) return MediaKind.kdrama;
    if (c.contains('c-drama') || c.contains('chinese drama')) {
      return MediaKind.cdrama;
    }
    if (c.contains('j-drama') || c.contains('japanese')) {
      return MediaKind.jdrama;
    }
    if (c.contains('manhwa') && !c.contains('manga')) return MediaKind.manhwa;
    if (c.contains('manhua')) return MediaKind.manhua;
    if (c.contains('series') || c.contains('show')) return MediaKind.series;
    if (c == 'manga' || c.contains('manga')) return MediaKind.manga;
    final s = sheet.toLowerCase();
    if (s.contains('anime')) return MediaKind.anime;
    if (s.contains('movie') || s.contains('film')) return MediaKind.movie;
    if (s.contains('series')) return MediaKind.series;
    if (s.contains('reading') || s.contains('manga') || s.contains('manhwa')) {
      return MediaKind.manga;
    }
    return null;
  }

  static LibraryState _state(String? raw, String sheet) {
    final s = (raw ?? '').toLowerCase();
    if (s.isEmpty) return LibraryState.seen;
    if (s.contains('caught up')) return LibraryState.caughtUp;
    if (s.contains('not started') || s.contains('plan') || s.contains('want')) {
      return LibraryState.planned;
    }
    if (s.contains('unconfirmed') || s.contains('played on')) {
      return s.contains('played') ? LibraryState.partial : LibraryState.seen;
    }
    if (s.contains('part')) return LibraryState.partial;
    if (s.contains('hold') || s.contains('paus')) return LibraryState.onHold;
    if (s.contains('drop')) return LibraryState.dropped;
    if (s.contains('watching')) return LibraryState.watching;
    if (s.contains('reading') && !s.contains('read (')) {
      return LibraryState.reading;
    }
    if (s.contains('finish') ||
        s.contains('complet') ||
        s.contains('binged') ||
        s.contains('watched') ||
        s.startsWith('read')) {
      return LibraryState.completed;
    }
    return LibraryState.seen;
  }

  static Rating? _rating(String? raw) {
    final s = (raw ?? '').toLowerCase();
    if (s.isEmpty) return null;
    if (s.contains('would rewatch')) return Rating.wouldRewatch;
    if (s.contains('rewatched')) return Rating.rewatched;
    if (s.contains('favourite') || s.contains('favorite')) {
      return Rating.favourite;
    }
    if (s.contains('dropped')) return Rating.dropped;
    if (s.contains('disliked') || s.contains('hated')) return Rating.disliked;
    if (s.contains('okay') ||
        s.contains('time-pass') ||
        s.contains('average')) {
      return Rating.okay;
    }
    if (s.contains('once') || s.contains('great') || s.contains('good')) {
      return Rating.once;
    }
    return null;
  }

  static DateTime? _month(String? raw) {
    final m = RegExp(r'^(\d{4})-(\d{2})').firstMatch(raw ?? '');
    return m == null ? null : DateTime.utc(int.parse(m[1]!), int.parse(m[2]!));
  }
}

/// Column positions found from header names.
class _Columns {
  _Columns(List<String> header) {
    int? find(bool Function(String) test) {
      for (var i = 0; i < header.length; i++) {
        if (test(header[i].trim().toLowerCase())) return i;
      }
      return null;
    }

    title = find((h) => h == 'title');
    alt = find(
      (h) =>
          h.contains('romaji') || h.contains('other name') || h.contains('alt'),
    );
    status = find((h) => h == 'status');
    rating = find((h) => h == 'rating');
    mood = find((h) => h.contains('rewatch mood'));
    year = find((h) => h == 'year');
    kind = find((h) => h == 'type' || h == 'kind');
    readTo = find((h) => h.contains('read to'));
    latest = find((h) => h.contains('latest'));
    plays = find((h) => h.contains('episode plays') || h == 'plays');
    last = find((h) => h.startsWith('last '));
    notes = find((h) => h == 'notes' || h == 'note');
  }

  late final int? title,
      alt,
      status,
      rating,
      mood,
      year,
      kind,
      readTo,
      latest,
      plays,
      last,
      notes;
}
