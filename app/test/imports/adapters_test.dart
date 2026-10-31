import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/imports/adapters/generic_csv.dart';
import 'package:cue/imports/adapters/list_api.dart';
import 'package:cue/imports/adapters/netflix_csv.dart';
import 'package:cue/imports/detect.dart';
import 'package:cue/imports/records.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protobuf/protobuf.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

const malAnime = '''<?xml version="1.0" encoding="UTF-8" ?>
<myanimelist>
  <myinfo><user_export_type>1</user_export_type></myinfo>
  <anime>
    <series_animedb_id>101</series_animedb_id>
    <series_title><![CDATA[Synthetic Show]]></series_title>
    <series_episodes>12</series_episodes>
    <my_watched_episodes>12</my_watched_episodes>
    <my_finish_date>2024-03-02</my_finish_date>
    <my_score>0</my_score>
    <my_status>Completed</my_status>
    <my_times_watched>0</my_times_watched>
  </anime>
  <anime>
    <series_animedb_id>102</series_animedb_id>
    <series_title>Another Synthetic</series_title>
    <my_finish_date>0000-00-00</my_finish_date>
    <my_score>9</my_score>
    <my_status>Watching</my_status>
    <my_times_watched>2</my_times_watched>
  </anime>
</myanimelist>''';

Uint8List mihonBackup() {
  List<int> msg(void Function(CodedBufferWriter) f) {
    final w = CodedBufferWriter();
    f(w);
    return w.toBuffer();
  }

  final chapter = msg((w) {
    w.writeField(4, PbFieldType.OB, true);
    w.writeField(9, PbFieldType.OF, 7.0);
  });
  final tracking = msg((w) {
    w.writeField(1, PbFieldType.O3, 2); // AniList
    // int64 on the wire is the same varint as int32 for small values.
    w.writeField(100, PbFieldType.O3, 555);
    w.writeField(4, PbFieldType.OS, 'https://tracker.example/token-like');
  });
  final manga = msg((w) {
    w.writeField(3, PbFieldType.OS, 'Synthetic Manhwa');
    w.writeField(16, PbFieldType.OY, chapter);
    w.writeField(18, PbFieldType.OY, tracking);
  });
  final prefs = msg((w) => w.writeField(1, PbFieldType.OS, 'secret-pref'));
  final backup = msg((w) {
    w.writeField(1, PbFieldType.OY, manga);
    w.writeField(104, PbFieldType.OY, prefs);
  });
  return Uint8List.fromList(const GZipEncoder().encode(backup));
}

void main() {
  group('detect', () {
    test('MAL XML, plain and gzipped', () {
      expect(detect(b(malAnime), 'x.xml').format, DetectedFormat.malXml);
      final gz = Uint8List.fromList(
        const GZipEncoder().encode(utf8.encode(malAnime)),
      );
      expect(detect(gz, 'animelist.xml.gz').format, DetectedFormat.malXml);
    });

    test('by bytes, not by name', () {
      expect(
        detect(b('Title,Date\nA,1/2/24'), 'notes.txt').format,
        DetectedFormat.netflixCsv,
      );
      expect(
        detect(
          b('{"cue":"backup","schema_version":1,"items":[]}'),
          'a.csv',
        ).format,
        DetectedFormat.cueBackup,
      );
      expect(
        detect(b('name;status\nA;done'), 'list.json').format,
        DetectedFormat.genericCsv,
      );
      expect(
        detect(mihonBackup(), 'backup.tachibk').format,
        DetectedFormat.mihonBackup,
      );
    });

    test('unknown files get the supported list, never an empty success', () {
      expect(
        () => detect(b('<html></html>'), 'x.html'),
        throwsA(
          isA<ImportRejected>().having(
            (e) => e.message,
            'm',
            contains('MyAnimeList'),
          ),
        ),
      );
      expect(
        () => detect(b('{"some":"json"}'), 'x.json'),
        throwsA(isA<ImportRejected>()),
      );
      expect(() => detect(Uint8List(0), 'x'), throwsA(isA<ImportRejected>()));
    });

    test('refuses gzip bombs by ratio', () {
      final bomb = Uint8List.fromList(
        const GZipEncoder().encode(List.filled(5 * 1024 * 1024, 0)),
      );
      expect(() => detect(bomb, 'x.gz'), throwsA(isA<ImportRejected>()));
    });
  });

  group('MAL XML', () {
    test('keeps ids, unscored stays unrated, unknown dates stay null', () {
      final p = parseDetected(detect(b(malAnime), 'x.xml'));
      final a = p.records[0];
      expect(a.malId, 101);
      expect(a.state, LibraryState.completed);
      expect(a.rating, isNull);
      expect(a.ratingOriginal, isNull);
      expect(a.actualWatchedAt, DateTime.utc(2024, 3, 2));
      final c = p.records[1];
      expect(c.rating, Rating.rewatched);
      expect(c.ratingOriginal, '9');
      expect(c.actualWatchedAt, isNull);
    });

    test('refuses DOCTYPE and ENTITY', () {
      const evil =
          '<?xml version="1.0"?><!DOCTYPE x [<!ENTITY e SYSTEM "file:///etc/passwd">]><myanimelist></myanimelist>';
      expect(
        () => parseDetected(detect(b(evil), 'x.xml')),
        throwsA(isA<ImportRejected>()),
      );
    });
  });

  group('Netflix CSV', () {
    const csv =
        'Title,Date\n'
        '"Synthetic Show: Season 1: Pilot","3/14/24"\n'
        '"Synthetic Show: Season 1: Two","3/15/24"\n'
        '"Synthetic Show: Season 1: Two","3/15/24"\n'
        '"A Film","1/2/24"\n';

    test(
      'groups episodes, dedupes identical rows, activity is not completion',
      () {
        final p = NetflixCsvAdapter().parse(b(csv));
        expect(p.records.length, 2);
        final show = p.records.firstWhere((r) => r.title == 'Synthetic Show');
        expect(show.plays, 2);
        expect(show.state, LibraryState.partial);
        expect(show.activityDate, DateTime.utc(2024, 3, 15));
        expect(p.warnings.single, contains('other people'));
        expect(p.dateRange!.$1, DateTime.utc(2024, 1, 2));
      },
    );

    test('ambiguous dates ask; a day above 12 decides', () {
      expect(
        NetflixCsvAdapter().parse(b('Title,Date\nA,03/04/24\n')).needsDateOrder,
        isTrue,
      );
      final dayFirst = NetflixCsvAdapter().parse(
        b('Title,Date\nA,25/04/24\nB,03/04/24\n'),
      );
      expect(dayFirst.needsDateOrder, isFalse);
      expect(
        dayFirst.records.firstWhere((r) => r.title == 'B').activityDate,
        DateTime.utc(2024, 4, 3),
      );
    });
  });

  group('Cue backup', () {
    test('schema v1, skips not_watched, compound rewatch moods', () {
      final json = jsonEncode({
        'cue': 'backup',
        'schema_version': 1,
        'items': [
          {
            'title': 'Synthetic A',
            'media': 'anime',
            'status': 'completed',
            'rating': 'rewatched',
            'rewatch_mood': 'Hype / nostalgia',
            'year': 2014,
          },
          {'title': 'Synthetic B', 'media': 'unknown', 'status': 'not_watched'},
          {
            'title': 'Synthetic C',
            'media': 'manhwa',
            'status': 'caught_up',
            'progress': {
              'unit': 'chapter',
              'read_to': 183,
              'latest_known': 190,
            },
          },
        ],
      });
      final p = parseDetected(detect(b(json), 'x.json'));
      expect(p.records.length, 2);
      expect(p.skipped, 1);
      expect(p.records[0].rewatchMood, RewatchMood.hype);
      expect(p.records[0].kind, MediaKind.anime);
      expect(p.records[1].progressValue, 183);
      expect(p.records[1].state, LibraryState.caughtUp);
    });

    test('refuses a newer schema', () {
      final json = jsonEncode({
        'cue': 'backup',
        'schema_version': 2,
        'items': [],
      });
      expect(
        () => parseDetected(detect(b(json), 'x.json')),
        throwsA(isA<ImportRejected>()),
      );
    });
  });

  group('generic CSV', () {
    test('guesses columns and reads values as text', () {
      final bytes = b(
        'Name;Status;Finished\n=HYPERLINK("x");Completed;2024-01-01\nPlain;watching;\n',
      );
      final adapter = GenericCsvAdapter();
      final m = adapter.guessMapping(bytes);
      expect(m.delimiter, ';');
      expect(m.status, 1);
      final p = adapter.parse(bytes, m);
      expect(p.records[0].title, '=HYPERLINK("x")');
      expect(p.records[0].state, LibraryState.completed);
      expect(p.records[1].state, LibraryState.watching);
    });
  });

  group('Mihon backup', () {
    test('keeps title, read marker and AniList id; skips everything else', () {
      final p = parseDetected(detect(mihonBackup(), 'b.tachibk'));
      final r = p.records.single;
      expect(r.title, 'Synthetic Manhwa');
      expect(r.anilistId, 555);
      expect(r.progressValue, 7);
      expect(r.state, LibraryState.reading);
      expect(r.toString(), isNot(contains('token-like')));
    });
  });

  group('list imports', () {
    test('normalises AniList entries', () {
      final p = parseListEntries('anilist', [
        {
          'anilistId': 1,
          'malId': 2,
          'title': 'Synthetic',
          'kind': 'anime',
          'status': 'completed',
          'score': 8,
          'repeat': 0,
          'completedAt': '2024-01-05',
        },
        {
          'anilistId': 3,
          'title': 'Planned One',
          'kind': 'manga',
          'status': 'planning',
          'score': null,
        },
      ]);
      expect(p.sourceType, 'anilist_api');
      expect(p.records[0].rating, Rating.once);
      expect(p.records[0].actualWatchedAt, DateTime.utc(2024, 1, 5));
      expect(p.records[1].state, LibraryState.planned);
      expect(p.records[1].rating, isNull);
    });
  });
}
