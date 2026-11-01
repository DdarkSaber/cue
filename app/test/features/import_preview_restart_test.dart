import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cue/app/router.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/features/imports/import_job.dart';
import 'package:cue/features/imports/import_screen.dart';
import 'package:cue/imports/detect.dart';
import 'package:cue/imports/import_draft.dart';
import 'package:cue/imports/import_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';

void main() {
  testWidgets(
    'a restored Netflix preview can correct dates and cancel durably',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final id = (await ProfileRepository(db).ensureActive()).id;
      final catalog = CatalogRepository(db, FakeGateway());
      await catalog.upsert([CatalogItemDto(item(1))]);
      final bytes = Uint8List.fromList(
        utf8.encode('Title,Date\nSynthetic 1,03/04/24\n'),
      );
      final parsed = parseDetected(detect(bytes, 'synthetic.csv'));
      expect(parsed.needsDateOrder, isTrue);
      final store = ImportDraftStore(db);
      final draft = await store.create(
        id,
        parsed,
        rawBytes: bytes,
        offlineOnly: true,
        dayFirst: false,
      );
      final staged = await ImportService(
        db,
        catalog,
      ).stage(id, parsed, offlineOnly: true);
      draft.matched = staged.matched;
      draft.existing = staged.existing;
      draft.ready = true;
      await store.save(id, draft);

      await pumpCue(t, db: db, location: CueRoutes.importer);
      final container = ProviderScope.containerOf(
        t.element(find.byType(ImportScreen)),
      );
      expect(find.text('How are dates written in this file?'), findsOneWidget);
      expect(
        container
            .read(importJobProvider)
            .staged!
            .parsed
            .records
            .single
            .activityDate,
        DateTime.utc(2024, 3, 4),
      );

      final ready = Completer<void>();
      final subscription = container.listen(importJobProvider, (_, job) {
        if (job.staged != null && job.dayFirst && !ready.isCompleted) {
          ready.complete();
        }
      });
      addTearDown(subscription.close);
      await t.tap(find.text('Day first (14/03/24)'));
      // Parsing uses a real isolate while the widget/database continuations
      // use the test clock. Advance both, bounded by five seconds of real time.
      for (var i = 0; i < 100 && !ready.isCompleted; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await t.pump();
      }
      expect(ready.isCompleted, isTrue);
      await t.pumpAndSettle();
      expect(
        container
            .read(importJobProvider)
            .staged!
            .parsed
            .records
            .single
            .activityDate,
        DateTime.utc(2024, 4, 3),
      );
      final corrected = await store.load(id);
      expect(corrected!.dayFirst, isTrue);
      expect(
        corrected.parsed.records.single.activityDate,
        DateTime.utc(2024, 4, 3),
      );
      expect(await db.select(db.userTitles).get(), isEmpty);

      await t.scrollUntilVisible(
        find.text('Cancel'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ImportScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(await store.load(id), isNull);
      expect(container.read(importJobProvider).idle, isTrue);
      expect(await db.select(db.userTitles).get(), isEmpty);
    },
  );
}
