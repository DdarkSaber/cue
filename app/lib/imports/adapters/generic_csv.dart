import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../../domain/models/library.dart';
import '../records.dart';

/// Which CSV columns mean what. Title is required; the rest are optional.
class CsvMapping {
  const CsvMapping({
    required this.title,
    this.status,
    this.date,
    this.rating,
    this.delimiter = ',',
  });

  final int title;
  final int? status;
  final int? date;
  final int? rating;
  final String delimiter;
}

/// Any CSV with a title column. Values are read as text; nothing is
/// evaluated, formulas included.
class GenericCsvAdapter {
  static const id = 'generic_csv';
  static const version = '1';

  String _delimiter(String firstLine) {
    final counts = {
      ',': ','.allMatches(firstLine).length,
      ';': ';'.allMatches(firstLine).length,
      '\t': '\t'.allMatches(firstLine).length,
    };
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  List<List<String>> rows(Uint8List bytes, [String? delimiter]) {
    final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('﻿', '');
    final d = delimiter ?? _delimiter(text.split('\n').first);
    final raw = CsvDecoder(
      fieldDelimiter: d,
      dynamicTyping: false,
    ).convert(text);
    if (raw.length > ImportLimits.maxRows) {
      throw const ImportRejected('This file has too many rows to read safely.');
    }
    return [
      for (final r in raw) [for (final c in r) cleanField(c.toString())],
    ];
  }

  /// Header names for the column picker.
  List<String> header(Uint8List bytes) {
    final r = rows(bytes);
    return r.isEmpty ? const [] : r.first;
  }

  CsvMapping guessMapping(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final d = _delimiter(text.split('\n').first);
    final h = header(bytes).map((s) => s.toLowerCase()).toList();
    int? find(List<String> names) {
      for (var i = 0; i < h.length; i++) {
        if (names.any((n) => h[i] == n || h[i].contains(n))) return i;
      }
      return null;
    }

    return CsvMapping(
      title: find(['title', 'name', 'series', 'show']) ?? 0,
      status: find(['status', 'state']),
      date: find(['date', 'finished', 'watched']),
      rating: find(['rating', 'score']),
      delimiter: d,
    );
  }

  ParsedImport parse(Uint8List bytes, CsvMapping m) {
    final all = rows(bytes, m.delimiter);
    final records = <NormalizedRecord>[];
    var skipped = 0;
    for (var i = 1; i < all.length; i++) {
      final r = all[i];
      String? col(int? c) =>
          c == null || c >= r.length || r[c].isEmpty ? null : r[c];
      final title = col(m.title);
      if (title == null) {
        skipped++;
        continue;
      }
      final status = col(m.status)?.toLowerCase();
      records.add(
        NormalizedRecord(
          sourceEntryKey: 'csv:${title.toLowerCase()}',
          title: title,
          state: _state(status),
          statusOriginal: status,
          ratingOriginal: col(m.rating),
          activityDate: _date(col(m.date)),
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

  static LibraryState _state(String? s) {
    if (s == null) return LibraryState.seen;
    if (s.contains('complet') || s.contains('finish') || s == 'done') {
      return LibraryState.completed;
    }
    if (s.contains('watching') ||
        s.contains('reading') ||
        s.contains('progress')) {
      return LibraryState.watching;
    }
    if (s.contains('plan') || s.contains('want')) return LibraryState.planned;
    if (s.contains('drop')) return LibraryState.dropped;
    if (s.contains('hold') || s.contains('pause')) return LibraryState.onHold;
    return LibraryState.seen;
  }

  static DateTime? _date(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    return m == null
        ? null
        : DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
}
