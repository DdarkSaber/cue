import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/imports/adapters/xlsx_import.dart';
import 'package:cue/imports/detect.dart';
import 'package:cue/imports/records.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a minimal .xlsx in memory: [sheets] maps a name to rows of cells.
/// A cell is a String (shared string), a num, or ('=f', cached) for a formula.
Uint8List buildXlsx(
  Map<String, List<List<Object?>>> sheets, {
  String extraXml = '',
}) {
  final shared = <String>[];
  int sst(String s) {
    final i = shared.indexOf(s);
    if (i >= 0) return i;
    shared.add(s);
    return shared.length - 1;
  }

  String colName(int i) => String.fromCharCode(65 + i);
  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  final names = sheets.keys.toList();
  for (var s = 0; s < names.length; s++) {
    final b = StringBuffer(
      '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
    );
    final rows = sheets[names[s]]!;
    for (var r = 0; r < rows.length; r++) {
      b.write('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        final v = rows[r][c];
        final ref = '${colName(c)}${r + 1}';
        if (v == null) continue;
        if (v is num) {
          b.write('<c r="$ref"><v>$v</v></c>');
        } else if (v is (String, Object)) {
          b.write('<c r="$ref"><f>${v.$1}</f><v>${v.$2}</v></c>');
        } else {
          b.write('<c r="$ref" t="s"><v>${sst('$v')}</v></c>');
        }
      }
      b.write('</row>');
    }
    b.write('</sheetData></worksheet>');
    add('xl/worksheets/sheet${s + 1}.xml', b.toString());
  }
  add(
    'xl/workbook.xml',
    '<?xml version="1.0"?>$extraXml<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
        '${[for (var s = 0; s < names.length; s++) '<sheet name="${names[s]}" sheetId="${s + 1}" r:id="rId${s + 1}"/>'].join()}'
        '</sheets></workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${[for (var s = 0; s < names.length; s++) '<Relationship Id="rId${s + 1}" Target="worksheets/sheet${s + 1}.xml"/>'].join()}'
        '</Relationships>',
  );
  add(
    'xl/sharedStrings.xml',
    '<?xml version="1.0"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '${[for (final s in shared) '<si><t>${const HtmlEscape().convert(s)}</t></si>'].join()}</sst>',
  );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  final workbook = buildXlsx({
    'Summary': [
      ['Synthetic history'],
      [],
      ['Sheet', 'Titles'],
      ['Anime', ('COUNTA(Anime!A:A)', 2)],
    ],
    'Anime': [
      ['Anime (franchises)'],
      ['Rating from the wall'],
      [],
      [
        'Title',
        'Romaji / other name',
        'Status',
        'Rating',
        'Rewatch mood',
        'Year',
      ],
      [
        'Synthetic Quest',
        'Shinteki Quest',
        'Finished',
        'Would rewatch',
        'Comfort',
        2018,
      ],
      ['Another Show', null, 'Watching', 'Once is enough', null, 2021],
      [null, null, 'Finished'],
    ],
    'Dramas': [
      ['K / C / J-dramas'],
      [],
      [],
      [
        'Title',
        'Type',
        'Status',
        'Rating',
        'Year',
        'Netflix episode plays',
        'Last played',
      ],
      [
        'Synthetic Drama',
        'K-drama',
        'Binged',
        'Rewatched',
        2022,
        153,
        '2025-09',
      ],
      [
        'Mandarin Story',
        'C-drama',
        'Part-watched',
        'Dropped midway',
        2020,
        null,
        null,
      ],
    ],
    'Reading': [
      ['Reading'],
      [],
      [],
      ['Title', 'Kind', 'Status', 'Read to (ch)', 'Latest (ch)'],
      ['Synthetic Tower', 'Manhwa', 'Reading', 120, 150],
      ['Mixed Label', 'Manga / manhwa', 'In library, not started', null, null],
    ],
    'Movies': [
      ['Movies'],
      [],
      [],
      ['Title', 'Status', 'Source'],
      ['Synthetic Film', 'Played on Netflix (unconfirmed)', 'Netflix'],
    ],
    'Not watched': [
      ['Titles you said you have not watched'],
      [],
      ['Title'],
      ['Skip Me'],
      ['Skip Me Too'],
    ],
  });

  group('xlsx import', () {
    test('is detected from bytes, whatever the file name', () {
      expect(detect(workbook, 'notes.txt').format, DetectedFormat.xlsx);
    });

    test('a zip that is not a spreadsheet is refused', () {
      final z = Archive()..addFile(ArchiveFile('a.txt', 1, [65]));
      expect(
        () => detect(Uint8List.fromList(ZipEncoder().encode(z)), 'a.zip'),
        throwsA(isA<ImportRejected>()),
      );
    });

    test(
      'finds the header row, reads each sheet and skips the Not watched one',
      () {
        final p = XlsxImportAdapter().parse(workbook);
        expect(p.sourceType, 'xlsx');
        expect(p.records.map((r) => r.title), [
          'Synthetic Quest',
          'Another Show',
          'Synthetic Drama',
          'Mandarin Story',
          'Synthetic Tower',
          'Mixed Label',
          'Synthetic Film',
        ]);
        expect(p.skipped, 3); // one blank-title row + two not-watched rows
        expect(p.warnings.single, contains('Not watched'));
      },
    );

    test('kinds come from the sheet name and the Type column', () {
      final byTitle = {
        for (final r in XlsxImportAdapter().parse(workbook).records) r.title: r,
      };
      expect(byTitle['Synthetic Quest']!.kind, MediaKind.anime);
      expect(byTitle['Synthetic Drama']!.kind, MediaKind.kdrama);
      expect(byTitle['Mandarin Story']!.kind, MediaKind.cdrama);
      expect(byTitle['Synthetic Tower']!.kind, MediaKind.manhwa);
      expect(byTitle['Mixed Label']!.kind, MediaKind.manga);
      expect(byTitle['Synthetic Film']!.kind, MediaKind.movie);
    });

    test(
      'status, rating, mood, progress and plays map without inventing data',
      () {
        final byTitle = {
          for (final r in XlsxImportAdapter().parse(workbook).records)
            r.title: r,
        };
        final q = byTitle['Synthetic Quest']!;
        expect(q.state, LibraryState.completed);
        expect(q.rating, Rating.wouldRewatch);
        expect(q.rewatchMood, RewatchMood.comfort);
        expect(q.year, 2018);
        expect(q.altTitles, ['Shinteki Quest']);
        expect(byTitle['Another Show']!.state, LibraryState.watching);
        expect(byTitle['Another Show']!.rewatchMood, isNull);

        final d = byTitle['Synthetic Drama']!;
        expect(d.state, LibraryState.completed);
        expect(d.rating, Rating.rewatched);
        expect(d.plays, 153);
        // A month is not a watch date: only activity, never actualWatchedAt.
        expect(d.activityDate, DateTime.utc(2025, 9));
        expect(d.actualWatchedAt, isNull);
        expect(byTitle['Mandarin Story']!.state, LibraryState.partial);
        expect(byTitle['Mandarin Story']!.rating, Rating.dropped);

        final t = byTitle['Synthetic Tower']!;
        expect(t.state, LibraryState.reading);
        expect(t.progressValue, 120);
        expect(t.latestKnown, 150);
        expect(byTitle['Mixed Label']!.state, LibraryState.planned);
        expect(byTitle['Mixed Label']!.progressValue, isNull);
        // "Played on Netflix (unconfirmed)" is activity, not completion.
        expect(byTitle['Synthetic Film']!.state, LibraryState.partial);
      },
    );

    test('formulas are never evaluated: only the saved value is read', () {
      final sheet = buildXlsx({
        'Anime': [
          ['Title', 'Status'],
          [('1+1', 'Cached Title'), 'Finished'],
        ],
      });
      expect(
        XlsxImportAdapter().parse(sheet).records.single.title,
        'Cached Title',
      );
    });

    test('a sheet with no Title column is an actionable error, not a silent success', () {
      final sheet = buildXlsx({
        'Stuff': [
          ['Name', 'Thing'],
          ['a', 'b'],
        ],
      });
      expect(
        () => XlsxImportAdapter().parse(sheet),
        throwsA(
          isA<ImportRejected>().having(
            (e) => e.message,
            'message',
            contains('Title'),
          ),
        ),
      );
    });

    test('DOCTYPE and ENTITY in a spreadsheet are refused', () {
      final evil = buildXlsx({
        'Anime': [
          ['Title'],
          ['x'],
        ],
      }, extraXml: '<!DOCTYPE x [<!ENTITY e SYSTEM "file:///etc/passwd">]>');
      expect(
        () => XlsxImportAdapter().parse(evil),
        throwsA(isA<ImportRejected>()),
      );
    });

    test('an expansion bomb is refused by ratio', () {
      final archive = Archive();
      final big = List<int>.filled(30 * 1024 * 1024, 0x20);
      archive.addFile(ArchiveFile('xl/workbook.xml', big.length, big));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      expect(
        () => XlsxImportAdapter().parse(bytes),
        throwsA(isA<ImportRejected>()),
      );
    });
  });
}
