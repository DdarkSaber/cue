import 'package:cue/app/theme.dart';
import 'package:cue/data/outcome_stats_repository.dart';
import 'package:cue/domain/learning/replay.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/features/settings/recommendation_quality_card.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const _recent = OutcomeStats(
  saved: 14,
  notInterested: 36,
  byKind: {
    MediaKind.anime: (saved: 9, rejected: 11),
    MediaKind.kdrama: (saved: 4, rejected: 22),
    // Too few to say anything about.
    MediaKind.movie: (saved: 1, rejected: 3),
  },
);

const _earlier = OutcomeStats(saved: 11, notInterested: 39);

ReplayReport _report(double auc) => ReplayReport(
  events: 200,
  positives: 60,
  auc: auc,
  logLoss: 0.6,
  precisionAt10: 0.4,
  baseRate: 0.3,
);

Future<void> _pump(
  WidgetTester tester,
  RecommendationQualityCard card, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = phoneSmall;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCueTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: card,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('empty state invites a few swipes', (tester) async {
    await _pump(
      tester,
      const RecommendationQualityCard(recent: OutcomeStats()),
    );
    expect(
      find.text(
        'Swipe a few cards and Cue will show how well its picks are landing.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Saved'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only watched or Not now answers is still the empty state', (
    tester,
  ) async {
    await _pump(
      tester,
      RecommendationQualityCard(
        recent: const OutcomeStats(watched: 3, notNow: 2),
        learned: _report(0.6),
        baseline: _report(0.5),
      ),
    );
    expect(find.text(RecommendationQualityCard.emptyText), findsOneWidget);
    expect(find.textContaining('Learning from your swipes'), findsNothing);
  });

  testWidgets('shows the save rate, trend, formats, days and comparison', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      RecommendationQualityCard(
        recent: _recent,
        earlier: _earlier,
        daily: [
          (day: DateTime(2026, 11, 9), saved: 2, rejected: 8),
          (day: DateTime(2026, 11, 11), saved: 5, rejected: 5),
          (day: DateTime(2026, 11, 12), saved: 0, rejected: 4),
        ],
        learned: _report(0.62),
        baseline: _report(0.51),
      ),
    );
    expect(find.text('Saved 14 of the last 50 cards (28%)'), findsOneWidget);
    expect(find.text('Up from 22%'), findsOneWidget);
    expect(find.text('Anime: saved 9 of 20 (45%)'), findsOneWidget);
    expect(find.text('K-drama: saved 4 of 26 (15%)'), findsOneWidget);
    expect(find.textContaining('Movie'), findsNothing);
    // Busiest format first.
    expect(
      tester.getTopLeft(find.textContaining('K-drama')).dy,
      lessThan(tester.getTopLeft(find.textContaining('Anime')).dy),
    );
    expect(find.text('9 Nov to 12 Nov'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Share of cards saved each day. 9 Nov: saved 2 of 10, '
        '11 Nov: saved 5 of 10, 12 Nov: saved 0 of 4.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Learning from your swipes would have ranked a card you saved above '
        'one you skipped 62% of the time, against 51% before.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('AUC'), findsNothing);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('says Down when the rate fell, nothing without earlier data', (
    tester,
  ) async {
    await _pump(
      tester,
      const RecommendationQualityCard(
        recent: _recent,
        earlier: OutcomeStats(saved: 31, notInterested: 69),
      ),
    );
    expect(find.text('Down from 31%'), findsOneWidget);

    await _pump(tester, const RecommendationQualityCard(recent: _recent));
    expect(find.textContaining('from'), findsNothing);
    expect(find.textContaining('Learning from'), findsNothing);

    // Two earlier answers are too few for a trend.
    await _pump(
      tester,
      const RecommendationQualityCard(
        recent: _recent,
        earlier: OutcomeStats(saved: 1, notInterested: 1),
      ),
    );
    expect(find.textContaining('from'), findsNothing);
  });

  testWidgets('names watched and Not now cards apart from the rate', (
    tester,
  ) async {
    await _pump(
      tester,
      const RecommendationQualityCard(
        recent: OutcomeStats(
          saved: 10,
          notInterested: 30,
          watched: 6,
          notNow: 4,
        ),
      ),
    );
    expect(find.text('Saved 10 of the last 40 cards (25%)'), findsOneWidget);
    expect(
      find.text(
        'Not counting 6 you had already watched or read and 4 set aside '
        'for later.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('no overflow at 360x740 with large text and 14 days', (
    tester,
  ) async {
    await _pump(
      tester,
      RecommendationQualityCard(
        recent: OutcomeStats(
          saved: 14,
          notInterested: 36,
          watched: 12,
          notNow: 9,
          byKind: {
            for (final k in MediaKind.discoverable) k: (saved: 7, rejected: 9),
          },
        ),
        earlier: _earlier,
        daily: [
          for (var d = 1; d <= 14; d++)
            (day: DateTime(2026, 11, d), saved: d % 4, rejected: 3),
        ],
        learned: _report(0.62),
        baseline: _report(0.51),
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('1 Nov to 14 Nov'), findsOneWidget);
    final card = tester.getRect(find.byType(RecommendationQualityCard));
    expect(card.right, lessThanOrEqualTo(360));
  });
}
