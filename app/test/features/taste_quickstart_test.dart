import 'package:cue/app/providers.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';

Future<void> _markSeen(WidgetTester t, CueDatabase db) => t.runAsync(() async {
  final repo = ProfileRepository(db);
  final p = await repo.ensureActive();
  await repo.setRawSetting(p.id, 'tasteQuickstartSeen', 'true');
});

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

void main() {
  final tile = find.byWidgetPredicate(
    (w) => w is Text && RegExp(r'^(Anime|Manhwa) \d+$').hasMatch(w.data ?? ''),
  );

  testWidgets('picks are saved as explicit Favourite ratings', (t) async {
    final db = memoryDb();
    addTearDown(db.close);
    await pumpCue(
      t,
      size: phoneSmall,
      location: '/taste',
      quickstart: true,
      db: db,
    );
    expect(find.text('Pick a few you loved'), findsOneWidget);
    expect(find.text('Pick at least one'), findsOneWidget);
    expect(tile, findsWidgets);

    await t.tap(tile.at(0));
    await t.tap(tile.at(1));
    await t.tap(tile.at(2));
    await t.pump();
    expect(find.textContaining('Save 3'), findsOneWidget);

    await t.tap(find.textContaining('Save 3'));
    await t.pumpAndSettle();

    final c = _container(t);
    final rows = await t.runAsync(() async {
      final id = await c.read(profileIdProvider.future);
      return c.read(libraryRepositoryProvider).entries(id);
    });
    expect(rows, hasLength(3));
    expect(rows!.every((r) => r.$1.rating == Rating.favourite), isTrue);
    expect(find.text('Pick a few you loved'), findsNothing);
  });

  testWidgets('search finds a title and a pick can be removed again', (
    t,
  ) async {
    final gateway = sampleGateway();
    gateway.searchResults['frieren'] = [item(900, title: 'Frieren')];
    await pumpCue(
      t,
      size: phoneSmall,
      location: '/taste',
      quickstart: true,
      gateway: gateway,
    );
    await t.enterText(find.byType(TextField), 'frieren');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    final result = find.text('Frieren 900');
    expect(result, findsOneWidget);
    await t.tap(result);
    await t.pump();
    expect(find.textContaining('Save 1'), findsOneWidget);
    await t.tap(result);
    await t.pump();
    expect(find.text('Pick at least one'), findsOneWidget);
  });

  testWidgets(
    'first run on an empty library opens the quickstart; skip leaves',
    (t) async {
      await pumpCue(t, size: phoneSmall, quickstart: true);
      expect(find.text('Pick a few you loved'), findsOneWidget);
      await t.tap(find.text('Skip for now'));
      await t.pumpAndSettle();
      expect(find.text('Pick a few you loved'), findsNothing);
      // A skipped quickstart stays reachable from the deck hint.
      expect(find.textContaining('Teach Cue your taste'), findsOneWidget);
      await t.tap(find.textContaining('Teach Cue your taste'));
      await t.pumpAndSettle();
      expect(find.text('Pick a few you loved'), findsOneWidget);
    },
  );

  testWidgets('it is not offered again once seen, and not in other tests', (
    t,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    await _markSeen(t, db);
    await pumpCue(t, size: phoneSmall, quickstart: true, db: db);
    expect(find.text('Pick a few you loved'), findsNothing);
    expect(find.textContaining('Teach Cue your taste'), findsOneWidget);
  });

  testWidgets('quickstart meets tap targets and fits 320x640 at 2x text', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pumpCue(
      t,
      size: const Size(320, 640),
      textScale: 2,
      location: '/taste',
      quickstart: true,
    );
    expect(t.takeException(), isNull);
    expect(find.text('Skip for now'), findsOneWidget);
    expect(find.text('Pick at least one'), findsOneWidget);
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
