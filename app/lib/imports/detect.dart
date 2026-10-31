import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'adapters/cue_backup.dart';
import 'adapters/generic_csv.dart';
import 'adapters/mal_xml.dart';
import 'adapters/mihon_backup.dart';
import 'adapters/netflix_csv.dart';
import 'adapters/xlsx_import.dart';
import 'adapters/xlsx_sheets.dart';
import 'records.dart';

/// Formats the upload button recognises, from bytes rather than the name.
enum DetectedFormat {
  malXml,
  netflixCsv,
  cueBackup,
  mihonBackup,
  genericCsv,
  xlsx,
}

/// Result of detection: the format and the (decompressed) bytes.
class Detected {
  const Detected(this.format, this.bytes);
  final DetectedFormat format;
  final Uint8List bytes;
}

const supportedList =
    'MyAnimeList XML (.xml or .xml.gz), Netflix viewing activity (.csv), '
    'Mihon or Tachiyomi backup (.tachibk), Cue backup (.json), or any CSV '
    'with a title column, or an Excel spreadsheet (.xlsx) with a Title column.';

/// Unwraps gzip with size and ratio bounds.
Uint8List gunzipBounded(Uint8List input) {
  final List<int> out;
  try {
    out = const GZipDecoder().decodeBytes(input);
  } on Object {
    throw const ImportRejected('The compressed file is damaged.');
  }
  if (out.length > ImportLimits.maxExpandedBytes ||
      out.length > input.length * ImportLimits.maxRatio) {
    throw const ImportRejected(
      'This file expands too much to read safely on this device.',
    );
  }
  return Uint8List.fromList(out);
}

/// Detection order: gzip (then MAL XML or Mihon inside), MAL XML root,
/// Netflix CSV header, Cue backup JSON, generic CSV.
Detected detect(Uint8List raw, String filename) {
  if (raw.isEmpty) throw const ImportRejected('The file is empty.');
  if (raw.length > ImportLimits.maxFileBytes) {
    throw const ImportRejected('Files up to 20 MB can be imported.');
  }
  var bytes = raw;
  var wasGzip = false;
  if (raw.length > 2 && raw[0] == 0x1F && raw[1] == 0x8B) {
    bytes = gunzipBounded(raw);
    wasGzip = true;
  }
  if (!wasGzip && looksLikeXlsx(bytes)) {
    // A zip is only read when it is a spreadsheet.
    if (latin1.decode(bytes, allowInvalid: true).contains('xl/workbook.xml')) {
      return Detected(DetectedFormat.xlsx, bytes);
    }
    throw const ImportRejected(
      'Cue does not recognise this zip file. $supportedList',
    );
  }
  final head = latin1.decode(
    bytes.sublist(0, bytes.length < 4096 ? bytes.length : 4096),
    allowInvalid: true,
  );
  final trimmed = head.replaceFirst('﻿', '').trimLeft();
  final lower = filename.toLowerCase();

  if (trimmed.startsWith('<')) {
    if (RegExp(r'<myanimelist[\s>]').hasMatch(trimmed)) {
      return Detected(DetectedFormat.malXml, bytes);
    }
    throw const ImportRejected(
      'Cue does not recognise this XML file. $supportedList',
    );
  }
  if (wasGzip &&
      (lower.endsWith('.tachibk') ||
          lower.endsWith('.proto.gz') ||
          MihonBackupAdapter.looksLikeBackup(bytes))) {
    return Detected(DetectedFormat.mihonBackup, bytes);
  }
  if (trimmed.startsWith('{')) {
    if (RegExp(r'"cue"\s*:\s*"backup"').hasMatch(head)) {
      return Detected(DetectedFormat.cueBackup, bytes);
    }
    throw const ImportRejected(
      'Cue reads its own backup JSON only. $supportedList',
    );
  }
  final firstLine = trimmed.split(RegExp(r'\r?\n')).first.trim();
  if (RegExp(r'^"?Title"?\s*,\s*"?Date"?$').hasMatch(firstLine)) {
    return Detected(DetectedFormat.netflixCsv, bytes);
  }
  if (firstLine.contains(',') ||
      firstLine.contains(';') ||
      firstLine.contains('\t')) {
    return Detected(DetectedFormat.genericCsv, bytes);
  }
  throw const ImportRejected(
    'Cue does not recognise this file. $supportedList',
  );
}

/// Parses a detected file with its adapter. Generic CSV needs a mapping.
ParsedImport parseDetected(
  Detected d, {
  CsvMapping? mapping,
  bool dayFirst = false,
}) {
  return switch (d.format) {
    DetectedFormat.malXml => MalXmlAdapter().parse(d.bytes),
    DetectedFormat.netflixCsv => NetflixCsvAdapter().parse(
      d.bytes,
      dayFirst: dayFirst,
    ),
    DetectedFormat.cueBackup => CueBackupAdapter().parse(d.bytes),
    DetectedFormat.xlsx => XlsxImportAdapter().parse(d.bytes),
    DetectedFormat.mihonBackup => MihonBackupAdapter().parse(d.bytes),
    DetectedFormat.genericCsv => GenericCsvAdapter().parse(
      d.bytes,
      mapping ?? GenericCsvAdapter().guessMapping(d.bytes),
    ),
  };
}
