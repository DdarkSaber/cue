import 'dart:math' as math;

import 'package:cue/features/deck/story_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// WCAG relative luminance of an opaque colour.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [top] painted over [bottom] (which is opaque).
Color _over(Color top, Color bottom) => Color.from(
  alpha: 1,
  red: top.r * top.a + bottom.r * (1 - top.a),
  green: top.g * top.a + bottom.g * (1 - top.a),
  blue: top.b * top.a + bottom.b * (1 - top.a),
);

const _white = Color(0xFFFFFFFF);

void main() {
  test('every card text colour reads at 4.5:1 on the scrim over white', () {
    // The scrim's lightest tone (where the text starts) over a pure white
    // poster: the worst case anywhere under the copy.
    final backdrop = _over(StoryCard.scrimMin, _white);
    expect(StoryCard.scrimMin.a, closeTo(0.85, 0.01));
    expect(StoryCard.scrimMax.a, greaterThan(StoryCard.scrimMin.a));
    for (final text in const [
      Color(0xFFF7F8FA), // title
      Color(0xFFC3CEDA), // meta and alternative title
      Color(0xFFE6F1FB), // reason
      Color(0xFFDAE4EE), // desktop genre eyebrow
    ]) {
      expect(_contrast(text, backdrop), greaterThanOrEqualTo(4.5));
    }
  });

  /// Checks every story card on screen: the copy sits inside the scrim
  /// body, the fade is above it, the title has a shadow, and each copy text
  /// colour reaches 4.5:1 on the scrim's lightest tone over white.
  void expectReadableCards(WidgetTester t, {bool titleOnCard = true}) {
    final cards = find.byType(StoryCard);
    expect(cards, findsWidgets);
    for (final card in cards.evaluate()) {
      final title = (card.widget as StoryCard).title;
      final ofCard = find.byElementPredicate((e) => e == card);
      final scrim = find.descendant(
        of: ofCard,
        matching: find.byKey(StoryCard.scrimKey),
      );
      final body = find.descendant(
        of: ofCard,
        matching: find.byKey(StoryCard.scrimBodyKey),
      );
      expect(scrim, findsOneWidget);
      expect(body, findsOneWidget);

      final heading = find.descendant(
        of: body,
        matching: find.text(title.displayTitle),
      );
      expect(heading, findsOneWidget, reason: 'title sits on the scrim');
      // The title is on the card, not clipped off its top.
      if (titleOnCard) {
        expect(
          t.getRect(heading).top,
          greaterThanOrEqualTo(t.getRect(ofCard).top),
        );
      }
      final style = t.widget<Text>(heading).style!;
      expect(style.shadows, isNotEmpty);

      final bodyRect = t.getRect(body);
      final gradient =
          (t.widget<DecoratedBox>(body).decoration as BoxDecoration).gradient!
              as LinearGradient;
      // The lightest stop of the scrim under the text, over white.
      final lightest = gradient.colors.reduce((a, b) => a.a <= b.a ? a : b);
      final backdrop = _over(lightest, _white);

      final texts = find.descendant(of: body, matching: find.byType(Text));
      expect(texts, findsWidgets);
      for (final e in texts.evaluate()) {
        final text = e.widget as Text;
        final rect = t.getRect(find.byElementPredicate((x) => x == e));
        expect(
          bodyRect.contains(rect.topLeft) &&
              bodyRect.contains(rect.bottomRight - const Offset(0.01, 0.01)),
          isTrue,
          reason: '"${text.data}" lies inside the scrim',
        );
        final color = text.style?.color;
        if (color == null) continue;
        // The era tag draws on its own tint; it is checked by colour only.
        expect(
          _contrast(color, backdrop),
          greaterThanOrEqualTo(4.5),
          reason: '"${text.data}" contrast over white poster',
        );
      }
      // The soft edge ends where the scrim body (and the text) begins.
      expect(t.getRect(scrim).top, lessThan(bodyRect.top));
    }
  }

  testWidgets('phone card copy sits on the scrim', (t) async {
    await pumpCue(t);
    expectReadableCards(t);
  });

  testWidgets('scrim holds at 320x640 and 2x text', (t) async {
    await pumpCue(t, size: const Size(320, 640), textScale: 2);
    expect(t.takeException(), isNull);
    // At 2x the copy is taller than this small card and its top is clipped
    // (as before the scrim); what shows is still on the scrim.
    expectReadableCards(t, titleOnCard: false);
  });

  testWidgets('desktop card copy sits on the scrim', (t) async {
    await pumpCue(t, size: desktop);
    expectReadableCards(t);
  });
}
