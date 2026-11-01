import 'package:cue/app/providers.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/features/deck/deck_controller.dart';
import 'package:cue/features/deck/mood_read_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  Future<ProviderContainer> typed(
    WidgetTester tester, {
    required bool smart,
  }) async {
    final gateway = sampleGateway();
    await pumpCue(tester, gateway: gateway);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(MoodReadChip)),
    );
    await c
        .read(settingsProvider.notifier)
        .change((s) => s.copyWith(smartMoodText: smart));
    c
        .read(deckFiltersProvider.notifier)
        .apply(const DeckFilters(tellMe: 'slow rom com'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }
    expect(gateway.moodHintCalls, smart ? ['slow rom com'] : isEmpty);
    return c;
  }

  testWidgets('typed mood text stays on the device by default', (tester) async {
    await typed(tester, smart: false);
  });

  testWidgets('with Smarter mood text on, only the sentence is sent', (
    tester,
  ) async {
    await typed(tester, smart: true);
  });
}
