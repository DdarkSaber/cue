import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/features/deck/deck_controller.dart';
import 'package:cue/features/deck/deck_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';
import 'deck_test.dart' show settle, waitForDecisions;

class _AnimeOnly extends DeckFiltersController {
  @override
  DeckFilters build() => const DeckFilters(kinds: {MediaKind.anime});
}

void main() {
  testWidgets(
    'a save steers the next cards toward what it recommends, one lookup at a time',
    (t) async {
      final gateway = FakeGateway(
        pages: {
          for (final kind in MediaKind.discoverable)
            if (kind != MediaKind.anime) kind: const [[]],
          MediaKind.anime: [
            [for (var i = 100; i < 160; i++) item(i)],
          ],
        },
      );
      // What people who liked any of these also liked: a different genre
      // and a lower score, so without the save they would not lead.
      final recommended = [
        for (var i = 900; i < 905; i++)
          item(i, genres: const ['Drama'], score: 65),
      ];
      for (var i = 100; i < 160; i++) {
        gateway.recommendationLists['anilist:$i'] = recommended;
      }
      await pumpCue(
        t,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_AnimeOnly.new)],
      );
      await settle(t);
      final container = ProviderScope.containerOf(
        t.element(find.byType(DeckScreen)),
      );
      final deck = container.read(deckControllerProvider.notifier);
      bool isRecommended(String id) => int.parse(id.split(':').last) >= 900;
      expect(
        container
            .read(deckControllerProvider)
            .cards
            .where((c) => isRecommended(c.title.id)),
        isEmpty,
      );
      expect(gateway.recommendationCalls, isEmpty);

      final saved = container.read(deckControllerProvider).top!.title.id;
      final first = deck.decide(Decision.willTry);
      await waitForDecisions(t, 1);
      await first;
      await settle(t);
      expect(gateway.recommendationCalls, ['anilist:${saved.split(':').last}']);
      final next = container.read(deckControllerProvider).cards.take(6);
      expect(
        next.where((c) => isRecommended(c.title.id)).length,
        greaterThanOrEqualTo(2),
        reason: next.map((c) => c.title.id).join(', '),
      );

      // A second save within 20 seconds does not ask again.
      final top = container.read(deckControllerProvider).top!;
      if (!isRecommended(top.title.id)) {
        final second = deck.decide(Decision.willTry);
        await waitForDecisions(t, 2);
        await second;
        await settle(t);
        expect(gateway.recommendationCalls, hasLength(1));
      }
    },
  );
}
