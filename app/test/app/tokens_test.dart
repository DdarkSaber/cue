import 'package:cue/app/layout.dart';
import 'package:cue/app/tokens.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cinema colour tokens match CUE-HANDOFF 4.1', () {
    const expected = {
      'bg': (CueColors.bg, 0xFF080A0D),
      'surface': (CueColors.surface, 0xFF171B20),
      'surfaceHigh': (CueColors.surfaceHigh, 0xFF1F262E),
      'line': (CueColors.line, 0x1FFFFFFF),
      'text': (CueColors.text, 0xFFF7F8FA),
      'textMuted': (CueColors.textMuted, 0xFFB7C0CC),
      'actionPrimary': (CueColors.actionPrimary, 0xFFF3F5F8),
      'onActionPrimary': (CueColors.onActionPrimary, 0xFF10151D),
      'accent': (CueColors.accent, 0xFFA9D7FF),
      'willTry': (CueColors.willTry, 0xFFB6DFCF),
      'notNow': (CueColors.notNow, 0xFFE2D4B8),
      'watched': (CueColors.watched, 0xFFC6D8ED),
      'notInterested': (CueColors.notInterested, 0xFFE8C7D0),
    };
    expected.forEach((name, pair) {
      test(name, () => expect(pair.$1.toARGB32(), pair.$2));
    });
  });

  test('text colours reach 4.5:1 on their surfaces', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final surface in [
      CueColors.bg,
      CueColors.surface,
      CueColors.surfaceHigh,
    ]) {
      expect(ratio(CueColors.text, surface), greaterThanOrEqualTo(4.5));
      expect(ratio(CueColors.textMuted, surface), greaterThanOrEqualTo(4.5));
    }
    expect(
      ratio(CueColors.onActionPrimary, CueColors.actionPrimary),
      greaterThanOrEqualTo(4.5),
    );
  });

  group('motion numbers match CUE-HANDOFF 4.4', () {
    test('commit distance is 25% of the card, clamped 72..120', () {
      expect(CueMotion.commitDistance(200), 72);
      expect(CueMotion.commitDistance(400), 100);
      expect(CueMotion.commitDistance(800), 120);
    });

    test('thresholds', () {
      expect(CueMotion.touchSlop, 8);
      expect(CueMotion.previewDistance, 18);
      expect(CueMotion.axisDominance, 1.35);
      expect(CueMotion.axisLock, 40);
      expect(CueMotion.flickVelocity, 900);
      expect(CueMotion.flickMinDistance, 32);
      expect(CueMotion.maxRotationDeg, 8);
      expect(CueMotion.nextCardScale, 0.972);
      expect(CueMotion.downRubberBandAfter, 60);
    });
  });

  test('spacing scale and minimum target', () {
    expect(
      [
        CueSpace.xs,
        CueSpace.sm,
        CueSpace.md,
        CueSpace.lg,
        CueSpace.xl,
        CueSpace.xxl,
      ],
      [4, 8, 12, 16, 24, 32],
    );
    expect(CueSize.minTarget, 48);
  });

  test('layout breakpoints', () {
    expect(layoutFor(360), CueLayout.phone);
    expect(layoutFor(699), CueLayout.phone);
    expect(layoutFor(700), CueLayout.tablet);
    expect(layoutFor(999), CueLayout.tablet);
    expect(layoutFor(1000), CueLayout.desktop);
  });
}
