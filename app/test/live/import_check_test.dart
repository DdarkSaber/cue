// Runs an import file through the real pipeline against the live catalogs and
// prints how well it matched. Skipped unless CUE_LIVE_FILE names a file, so
// personal data never lives in the repository.
//
//   CUE_LIVE_FILE=path/to/file.xlsx flutter test test/live/import_check_test.dart
import 'dart:io';

import 'package:cue/data/anilist_client.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/imports/detect.dart';
import 'package:cue/imports/import_service.dart';
import 'package:cue/imports/matcher.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  final path = Platform.environment['CUE_LIVE_FILE'];
  final worker =
      Platform.environment['CUE_LIVE_API'] ??
      'https://cue-worker.cue-worker.workers.dev';

  test(
    'live import check',
    () async {
      final bytes = File(path!).readAsBytesSync();
      final parsed = parseDetected(
        detect(bytes, path.split(RegExp(r'[\\/]')).last),
      );
      final db = memoryDb();
      addTearDown(db.close);
      final profile = (await ProfileRepository(db).ensureActive()).id;
      final catalog = CatalogRepository(
        db,
        HybridCatalogGateway(HttpCatalogGateway(worker), AniListClient()),
      );
      final sw = Stopwatch()..start();
      final staged = await ImportService(db, catalog).stage(
        profile,
        parsed,
        rawBytes: bytes,
        onProgress: (d, t) {
          if (d % 100 == 0 || d == t) stdout.writeln('  matched $d / $t');
        },
      );
      sw.stop();

      final byKind = <String, Map<MatchClass, int>>{};
      for (final m in staged.matched) {
        final k = m.record.kind?.name ?? 'unknown';
        final row = byKind.putIfAbsent(k, () => {});
        row[m.matchClass] = (row[m.matchClass] ?? 0) + 1;
      }
      stdout
        ..writeln('')
        ..writeln(
          'source ${parsed.sourceType}: ${parsed.records.length} records, '
          '${parsed.skipped} skipped, ${sw.elapsed.inSeconds}s',
        )
        ..writeln(
          '${'kind'.padRight(9)} total  exact  similar  none  auto-rate  with-similar',
        );
      var total = 0, exact = 0, similar = 0;
      for (final e in byKind.entries) {
        final c = e.value;
        final n = c.values.fold(0, (a, b) => a + b);
        final ex =
            n - (c[MatchClass.similar] ?? 0) - (c[MatchClass.unresolved] ?? 0);
        final si = c[MatchClass.similar] ?? 0;
        total += n;
        exact += ex;
        similar += si;
        stdout.writeln(
          '${e.key.padRight(9)} ${'$n'.padLeft(5)} ${'$ex'.padLeft(6)} ${'$si'.padLeft(8)} '
          '${'${n - ex - si}'.padLeft(5)}  ${(100 * ex / n).toStringAsFixed(0).padLeft(7)}%  '
          '${(100 * (ex + si) / n).toStringAsFixed(0).padLeft(8)}%',
        );
      }
      stdout.writeln(
        'overall: $exact exact (${(100 * exact / total).toStringAsFixed(1)}%), '
        '$similar similar, ${total - exact - similar} none, '
        '${staged.unchecked} not checked',
      );
      stdout.writeln('\nsimilar matches to eyeball:');
      for (final m
          in staged.matched
              .where((m) => m.matchClass == MatchClass.similar)
              .take(60)) {
        stdout.writeln(
          '  [${m.record.kind?.name}] ${m.record.title}  ->  ${m.candidateName}',
        );
      }
      final miss = staged.matched.where((m) => !m.resolved).toList();
      stdout.writeln('\nno match (${miss.length}):');
      for (final m in miss.take(60)) {
        stdout.writeln('  [${m.record.kind?.name ?? '?'}] ${m.record.title}');
      }
      expect(total, greaterThan(0));
    },
    skip: path == null ? 'set CUE_LIVE_FILE to run' : false,
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
