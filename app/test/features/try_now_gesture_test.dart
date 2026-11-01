import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/ranker.dart';
import 'package:cue/features/deck/swipe_deck.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const title = Title(
    id: 'synthetic:try-now',
    kind: MediaKind.anime,
    titleEn: 'Synthetic story',
  );
  const card = RankedCard(title, 1, 'A synthetic reason.');

  Future<void> pumpDeck(
    WidgetTester tester, {
    void Function(String)? onTryNow,
    void Function(SwipeDirection)? onSwipe,
    VoidCallback? onDetails,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 560,
              child: SwipeDeck(
                cards: const [card],
                swipeMap: SwipeMap.standard,
                onSwipe: onSwipe ?? (_) {},
                onDetails: onDetails ?? () {},
                onTryNow: onTryNow,
                reduceMotion: reduceMotion,
                haptics: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final surface = find.byKey(
    const ValueKey('story-card-actions-synthetic:try-now'),
  );

  testWidgets('double-tap invokes Try now once for the captured title', (
    tester,
  ) async {
    final tried = <String>[];
    final swipes = <SwipeDirection>[];
    var details = 0;
    await pumpDeck(
      tester,
      onTryNow: tried.add,
      onSwipe: swipes.add,
      onDetails: () => details++,
    );

    await tester.tap(surface);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(surface);
    await tester.pumpAndSettle();

    expect(tried, ['synthetic:try-now']);
    expect(swipes, isEmpty);
    expect(details, 0);
  });

  testWidgets('single tap opens details after the double-tap window', (
    tester,
  ) async {
    final tried = <String>[];
    var details = 0;
    await pumpDeck(tester, onTryNow: tried.add, onDetails: () => details++);

    await tester.tap(surface);
    expect(details, 0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(details, 1);
    expect(tried, isEmpty);
  });

  testWidgets('a drag still wins the gesture arena and performs a swipe', (
    tester,
  ) async {
    final tried = <String>[];
    final swipes = <SwipeDirection>[];
    await pumpDeck(tester, onTryNow: tried.add, onSwipe: swipes.add);

    await tester.drag(surface, const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(swipes, [SwipeDirection.up]);
    expect(tried, isEmpty);
  });

  testWidgets('all four drags still report their original directions', (
    tester,
  ) async {
    final tried = <String>[];
    final swipes = <SwipeDirection>[];
    var details = 0;
    await pumpDeck(
      tester,
      onTryNow: tried.add,
      onSwipe: swipes.add,
      onDetails: () => details++,
    );

    for (final direction in [
      SwipeDirection.right,
      SwipeDirection.down,
      SwipeDirection.up,
      SwipeDirection.left,
    ]) {
      final offset = switch (direction) {
        SwipeDirection.right => const Offset(200, 0),
        SwipeDirection.down => const Offset(0, 200),
        SwipeDirection.up => const Offset(0, -200),
        SwipeDirection.left => const Offset(-200, 0),
      };
      await tester.drag(surface, offset);
      await tester.pumpAndSettle();
    }

    expect(swipes, [
      SwipeDirection.right,
      SwipeDirection.down,
      SwipeDirection.up,
      SwipeDirection.left,
    ]);
    expect(tried, isEmpty);
    expect(details, 0);
  });

  testWidgets('without Try now, a background tap keeps its prior behavior', (
    tester,
  ) async {
    var details = 0;
    await pumpDeck(tester, onDetails: () => details++);

    await tester.tap(surface);
    await tester.pump(const Duration(milliseconds: 400));

    expect(details, 0);
  });

  testWidgets('reduced motion does not change Try now into a swipe', (
    tester,
  ) async {
    final tried = <String>[];
    final swipes = <SwipeDirection>[];
    await pumpDeck(
      tester,
      onTryNow: tried.add,
      onSwipe: swipes.add,
      reduceMotion: true,
    );

    await tester.tap(surface);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(surface);
    await tester.pumpAndSettle();

    expect(tried, ['synthetic:try-now']);
    expect(swipes, isEmpty);
  });

  testWidgets('Try now is exposed as a custom screen-reader action', (
    tester,
  ) async {
    final tried = <String>[];
    final semantics = tester.ensureSemantics();
    try {
      await pumpDeck(tester, onTryNow: tried.add);
      await tester.pump();

      final node = tester.getSemantics(
        find.byKey(const ValueKey('story-card-actions-synthetic:try-now')),
      );
      final actionId = CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: 'Try now'),
      );
      expect(
        node.getSemanticsData().customSemanticsActionIds,
        contains(actionId),
      );

      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        actionId,
      );
      expect(tried, ['synthetic:try-now']);
    } finally {
      semantics.dispose();
    }
  });
}
