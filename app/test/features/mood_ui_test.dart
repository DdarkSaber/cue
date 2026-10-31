import 'package:cue/app/providers.dart';
import 'package:cue/domain/mood/mood_target.dart';
import 'package:cue/features/deck/mood_read_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('the Cue read chip shows only with a confident guess', (
    tester,
  ) async {
    await pumpCue(tester);
    expect(find.textContaining('Cue read'), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MoodReadChip)),
    );
    container
        .read(moodReadProvider.notifier)
        .set(const MoodTarget({'isekai': 1}, 0.2, label: 'Isekai'));
    await tester.pump();
    expect(find.textContaining('Cue read'), findsNothing);
    container
        .read(moodReadProvider.notifier)
        .set(
          const MoodTarget({'isekai': 1}, 0.8, label: 'Isekai', modeId: 'm'),
        );
    await tester.pump();
    expect(find.text('Cue read: Isekai'), findsOneWidget);
  });

  testWidgets('Privacy can clear mood learning', (tester) async {
    await pumpCue(tester, location: '/settings/privacy');
    final button = find.text('Clear mood learning');
    await tester.scrollUntilVisible(button, 200);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.text('Mood learning cleared.', skipOffstage: false),
      findsOneWidget,
    );
  });
}
