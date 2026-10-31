import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../../domain/models/library.dart';
import '../records.dart';

/// Netflix viewing activity CSV (Title,Date). Rows are viewing
/// observations, not ratings or completion. Episodes group into a show by
/// the text before the first colon.
class NetflixCsvAdapter {
  static const id = 'netflix_csv';
  static const version = '1';

  /// True when every date could be either order (e.g. 03/04/24).
  static bool ambiguousDates(Uint8List bytes) {
    final rows = _rows(bytes);
    var dayFirstPossible = true, monthFirstPossible = true, sawDate = false;
    for (final r in rows.skip(1)) {
      if (r.length < 2) continue;
      final p = _parts(r[1].toString());
      if (p == null) continue;
      sawDate = true;
      if (p.$1 > 12) monthFirstPossible = false;
      if (p.$2 > 12) dayFirstPossible = false;
    }
    return sawDate && dayFirstPossible && monthFirstPossible;
  }

  /// Whether the file itself proves day-first order.
  static bool impliesDayFirst(Uint8List bytes) {
    for (final r in _rows(bytes).skip(1)) {
      if (r.length < 2) continue;
      final p = _parts(r[1].toString());
      if (p != null && p.$1 > 12) return true;
    }
    return false;
  }

  static List<List<dynamic>> _rows(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('﻿', '');
    return const CsvDecoder(dynamicTyping: false).convert(text);
  }

  static (int, int, int)? _parts(String s) {
    final m = RegExp(r'^\s*(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})\s*$')
        .firstMatch(s);
    if (m == null) return null;
    var y = int.parse(m[3]!);
    if (y < 100) y += 2000;
    return (int.parse(m[1]!), int.parse(m[2]!), y);
  }

  ParsedImport parse(Uint8List bytes, {bool dayFirst = false}) {
    final rows = _rows(bytes);
    if (rows.length > ImportLimits.maxRows) {
      throw const ImportRejected('This file has too many rows to read safely.');
    }
    final effectiveDayFirst = dayFirst || impliesDayFirst(bytes);
    final shows = <String, _Show>{};
    final seenRows = <String>{};
    var skipped = 0;
    DateTime? first, last;
    for (final r in rows.skip(1)) {
      if (r.isEmpty) continue;
      final rawTitle = cleanField(r[0].toString());
      if (rawTitle.isEmpty) {
        skipped++;
        continue;
      }
      final date = r.length > 1
          ? _date(r[1].toString(), effectiveDayFirst)
          : null;
      // Identical rows are duplicates; distinct dates are distinct plays.
      if (!seenRows.add('$rawTitle|${r.length > 1 ? r[1] : ''}')) continue;
      final show = rawTitle.split(':').first.trim();
      final s = shows.putIfAbsent(show.toLowerCase(), () => _Show(show));
      s.plays++;
      if (rawTitle.contains(':')) s.episodic = true;
      if (date != null) {
        if (s.last == null || date.isAfter(s.last!)) s.last = date;
        if (first == null || date.isBefore(first)) first = date;
        if (last == null || date.isAfter(last)) last = date;
      }
    }
    final records = [
      for (final s in shows.values)
        NormalizedRecord(
          sourceEntryKey: 'netflix:${s.name.toLowerCase()}',
          title: s.name,
          // Activity only: watching some of it is not completing it.
          state: LibraryState.partial,
          statusOriginal: 'activity',
          plays: s.plays,
          activityDate: s.last,
        ),
    ];
    return ParsedImport(
      sourceType: id,
      adapterVersion: version,
      records: records,
      skipped: skipped,
      dateRange: first == null ? null : (first, last!),
      needsDateOrder: !effectiveDayFirst && ambiguousDates(bytes),
      warnings: const [
        'This history may include other people. Review before using it for your taste.',
      ],
    );
  }

  /// Date only, no invented time zone.
  static DateTime? _date(String s, bool dayFirst) {
    final iso = RegExp(r'^\s*(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (iso != null) {
      return DateTime.utc(
        int.parse(iso[1]!),
        int.parse(iso[2]!),
        int.parse(iso[3]!),
      );
    }
    final p = _parts(s);
    if (p == null) return null;
    final (a, b, y) = p;
    final (d, m) = dayFirst ? (a, b) : (b, a);
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime.utc(y, m, d);
  }
}

class _Show {
  _Show(this.name);
  final String name;
  int plays = 0;
  bool episodic = false;
  DateTime? last;
}
