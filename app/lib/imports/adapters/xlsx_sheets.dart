import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../records.dart';

/// One worksheet as plain text rows. Cells are text only: formulas are never
/// evaluated, only the cached value the spreadsheet saved is read.
class SheetData {
  const SheetData(this.name, this.rows);
  final String name;
  final List<List<String>> rows;
}

bool looksLikeXlsx(Uint8List bytes) =>
    bytes.length > 4 &&
    bytes[0] == 0x50 &&
    bytes[1] == 0x4B &&
    bytes[2] == 0x03 &&
    bytes[3] == 0x04;

/// Column letters to a zero-based index ("A" 0, "AA" 26).
int columnIndex(String ref) {
  var n = 0;
  for (final c in ref.codeUnits) {
    if (c < 65 || c > 90) break;
    n = n * 26 + (c - 64);
  }
  return n - 1;
}

XmlDocument _xml(ArchiveFile f) {
  final text = utf8.decode(f.content as List<int>, allowMalformed: true);
  if (RegExp(r'<!DOCTYPE|<!ENTITY', caseSensitive: false).hasMatch(text)) {
    throw const ImportRejected(
      'This spreadsheet declares a DOCTYPE or ENTITY, which Cue refuses for safety.',
    );
  }
  try {
    return XmlDocument.parse(text);
  } on XmlException {
    throw const ImportRejected('This spreadsheet is damaged.');
  }
}

/// Reads every worksheet of an .xlsx file, bounded in size and rows.
List<SheetData> readXlsx(Uint8List bytes) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } on Object {
    throw const ImportRejected('This spreadsheet could not be opened.');
  }
  var expanded = 0;
  for (final f in zip.files) {
    expanded += f.size;
    if (expanded > ImportLimits.maxExpandedBytes ||
        expanded > bytes.length * ImportLimits.maxRatio) {
      throw const ImportRejected(
        'This spreadsheet expands too much to read safely on this device.',
      );
    }
  }
  ArchiveFile? entry(String name) {
    for (final f in zip.files) {
      if (f.isFile && f.name == name) return f;
    }
    return null;
  }

  final workbook = entry('xl/workbook.xml');
  if (workbook == null) {
    throw const ImportRejected('This is not a spreadsheet Cue can read.');
  }

  final shared = <String>[];
  final sst = entry('xl/sharedStrings.xml');
  if (sst != null) {
    for (final si in _xml(sst).findAllElements('si')) {
      // Rich text splits one string into runs; join them.
      shared.add(si.findAllElements('t').map((t) => t.innerText).join());
    }
  }

  final rels = <String, String>{};
  final relsFile = entry('xl/_rels/workbook.xml.rels');
  if (relsFile != null) {
    for (final r in _xml(relsFile).findAllElements('Relationship')) {
      final id = r.getAttribute('Id');
      final target = r.getAttribute('Target');
      if (id != null && target != null) rels[id] = target;
    }
  }

  final sheets = <SheetData>[];
  var rowCount = 0;
  for (final s in _xml(workbook).findAllElements('sheet')) {
    final name = cleanField(s.getAttribute('name'));
    final rid = s.attributes
        .where((a) => a.name.local == 'id')
        .map((a) => a.value)
        .firstOrNull;
    var target = rid == null ? null : rels[rid];
    if (target == null) continue;
    target = target.startsWith('/') ? target.substring(1) : 'xl/$target';
    final file = entry(target);
    if (file == null) continue;
    final rows = <List<String>>[];
    for (final row in _xml(file).findAllElements('row')) {
      if (++rowCount > ImportLimits.maxRows) {
        throw const ImportRejected(
          'This spreadsheet has too many rows to read safely.',
        );
      }
      final cells = <int, String>{};
      var next = 0;
      for (final c in row.findElements('c')) {
        final ref = c.getAttribute('r');
        final col = ref == null ? next : columnIndex(ref);
        next = col + 1;
        if (col < 0 || col > 200) continue;
        final type = c.getAttribute('t');
        String text;
        if (type == 'inlineStr') {
          text = c.findAllElements('t').map((t) => t.innerText).join();
        } else {
          final v = c.getElement('v')?.innerText ?? '';
          text = type == 's'
              ? (shared.elementAtOrNull(int.tryParse(v) ?? -1) ?? '')
              : v;
        }
        cells[col] = cleanField(text);
      }
      if (cells.isEmpty) {
        rows.add(const []);
        continue;
      }
      final width = cells.keys.reduce((a, b) => a > b ? a : b) + 1;
      rows.add([for (var i = 0; i < width; i++) cells[i] ?? '']);
    }
    sheets.add(SheetData(name, rows));
  }
  return sheets;
}
