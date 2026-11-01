import 'package:cue/app/providers.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/quick_mood.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/features/deck/deck_controller.dart';
import 'package:cue/features/deck/mood_read_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';
import '../support/import_union.dart';

void main() {
  testWidgets(
    'merged history stays out; Revisit and comedy filters are explicit',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final fixture = (await t.runAsync(() => seedImportUnion(db)))!;
      await pumpCue(t, db: db, gateway: fixture.gateway);
      final c = ProviderScope.containerOf(t.element(find.byType(MoodReadChip)));
      await c
          .read(settingsProvider.notifier)
          .change((s) => s.copyWith(includeRewatches: true));
      await t.pumpAndSettle();
      final fresh = c.read(deckControllerProvider).cards;
      expect(fresh, isNotEmpty);
      expect(
        fresh.any((card) => fixture.historyIds.contains(card.title.id)),
        isFalse,
      );

      await t.tap(find.text('Tell me…'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'fast paced comedy kdrama');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(find.text('Show me').hitTestable(), findsOneWidget);
      await t.tap(find.text('Show me'));
      await t.pumpAndSettle();
      final filters = c.read(deckFiltersProvider);
      expect(filters.kinds, {MediaKind.kdrama});
      expect(filters.genres, {'comedy'});
      final comedies = c.read(deckControllerProvider).cards;
      expect(comedies, hasLength(2));
      expect(
        comedies.every((card) => card.title.kind == MediaKind.kdrama),
        isTrue,
      );
      expect(
        comedies.every((card) => card.title.genres.contains('Comedy')),
        isTrue,
      );
      expect(find.textContaining('Cue read: Action'), findsNothing);

      c
          .read(deckFiltersProvider.notifier)
          .apply(
            const DeckFilters(
              mood: QuickMood.revisit,
              kinds: {MediaKind.anime},
            ),
          );
      await t.pumpAndSettle();
      expect(
        c.read(deckControllerProvider).cards.map((card) => card.title.id),
        ['anilist:1'],
      );
      c.read(deckFiltersProvider.notifier).apply(const DeckFilters());
      await t.pumpAndSettle();
      expect(
        c
            .read(deckControllerProvider)
            .cards
            .any((card) => fixture.historyIds.contains(card.title.id)),
        isFalse,
      );
    },
  );
}
