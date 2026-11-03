import 'package:cue/app/providers.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/settings.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/features/deck/deck_screen.dart';
import 'package:cue/features/deck/candidate_sources.dart' show AiPicksPrompt;
import 'package:flutter/widgets.dart' show SizedBox, Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';
import 'deck_test.dart' show settle;

FakeGateway _gateway() => FakeGateway(
  pages: {
    for (final k in MediaKind.discoverable)
      if (k != MediaKind.anime) k: const [[]],
    MediaKind.anime: [
      [for (var i = 1; i <= 12; i++) item(i)],
    ],
  },
);

Future<void> _library(WidgetTester t, CueDatabase db, int liked) =>
    t.runAsync(() async {
      final profile = (await ProfileRepository(db).ensureActive()).id;
      await CatalogRepository(
        db,
        FakeGateway(),
      ).upsert([for (var i = 1; i <= 12; i++) CatalogItemDto(item(i))]);
      final library = LibraryRepository(db);
      for (var i = 1; i <= liked; i++) {
        await library.saveEntry(
          profile,
          'anilist:$i',
          state: LibraryState.completed,
          rating: Rating.favourite,
        );
      }
    });

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(DeckScreen)));

void main() {
  testWidgets('shown with enough liked titles; Turn on enables the toggle', (
    t,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    await _library(t, db, 5);
    await pumpCue(t, db: db, gateway: _gateway());
    await settle(t);
    expect(find.text('Want picks that understand your taste?'), findsOneWidget);
    await t.tap(find.text('Turn on'));
    await settle(t);
    final s = _container(t).read(currentSettingsProvider);
    expect(s.aiPicks, isTrue);
    expect(s.aiPicksPromptSeen, isTrue);
    expect(find.text('Want picks that understand your taste?'), findsNothing);
  });

  testWidgets('Not now hides it for good and leaves the toggle off', (t) async {
    final db = memoryDb();
    addTearDown(db.close);
    await _library(t, db, 5);
    await pumpCue(t, db: db, gateway: _gateway());
    await settle(t);
    expect(find.text('Want picks that understand your taste?'), findsOneWidget);
    await t.tap(
      find.descendant(
        of: find.byType(AiPicksPrompt),
        matching: find.text('Not now'),
      ),
    );
    await settle(t);
    expect(find.text('Want picks that understand your taste?'), findsNothing);
    final s = _container(t).read(currentSettingsProvider);
    expect(s.aiPicks, isFalse);
    expect(s.aiPicksPromptSeen, isTrue);

    // A fresh session over the same database never asks again.
    await t.pumpWidget(const SizedBox());
    await pumpCue(t, db: db, gateway: _gateway());
    await settle(t);
    expect(find.text('Want picks that understand your taste?'), findsNothing);
  });

  testWidgets('hidden with too little taste or when already on', (t) async {
    final db = memoryDb();
    addTearDown(db.close);
    await _library(t, db, 4);
    await pumpCue(t, db: db, gateway: _gateway());
    await settle(t);
    expect(find.text('Want picks that understand your taste?'), findsNothing);

    final on = memoryDb();
    addTearDown(on.close);
    await _library(t, on, 5);
    await t.runAsync(() async {
      final repo = ProfileRepository(on);
      final id = (await repo.ensureActive()).id;
      await repo.saveSettings(id, const AppSettings(aiPicks: true));
    });
    await t.pumpWidget(const SizedBox());
    await pumpCue(t, db: on, gateway: _gateway());
    await settle(t);
    expect(find.text('Want picks that understand your taste?'), findsNothing);
  });

  testWidgets('the prompt fits 320x640 without overflow', (t) async {
    final db = memoryDb();
    addTearDown(db.close);
    await _library(t, db, 5);
    await pumpCue(t, db: db, gateway: _gateway(), size: const Size(320, 640));
    await settle(t);
    expect(find.text('Want picks that understand your taste?'), findsOneWidget);
    expect(t.takeException(), isNull);
    final turnOn = find.text('Turn on');
    expect(turnOn.hitTestable(), findsOneWidget);
    expect(t.getRect(turnOn).right, lessThanOrEqualTo(320));
    expect(t.getRect(find.byType(AiPicksPrompt)).right, lessThanOrEqualTo(320));
  });
}
