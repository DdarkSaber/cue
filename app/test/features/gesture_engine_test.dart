import 'package:cue/domain/models/decision.dart';
import 'package:cue/features/deck/gesture_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const card = Size(360, 560);

  GestureEngine dragged(Offset to) {
    final g = GestureEngine()..start();
    // Feed intermediate points like a real drag.
    for (var i = 1; i <= 10; i++) {
      g.update(to * (i / 10));
    }
    return g;
  }

  test('no preview inside 18 px', () {
    expect(dragged(const Offset(15, 0)).preview, isNull);
  });

  test('previews the dominant axis after 18 px', () {
    expect(dragged(const Offset(30, 5)).preview, SwipeDirection.right);
    expect(dragged(const Offset(-4, -30)).preview, SwipeDirection.up);
  });

  test('a diagonal without a clear axis never commits', () {
    final g = dragged(const Offset(100, 90));
    expect(
      g.release(const Offset(100, 90), const Offset(2000, 2000), card),
      isNull,
    );
  });

  test('commits at 25% of the card, clamped to 72-120 px', () {
    final g = dragged(const Offset(91, 0));
    expect(
      g.release(const Offset(91, 0), Offset.zero, card),
      SwipeDirection.right,
    );
    final short = dragged(const Offset(70, 0));
    expect(short.release(const Offset(70, 0), Offset.zero, card), isNull);
  });

  test('a flick commits above 900 px/s after 32 px in the same direction', () {
    final g = dragged(const Offset(-40, 0));
    expect(
      g.release(const Offset(-40, 0), const Offset(-1200, 0), card),
      SwipeDirection.left,
    );
  });

  test('velocity alone never commits a tap', () {
    final g = dragged(const Offset(10, 0));
    expect(g.release(const Offset(10, 0), const Offset(3000, 0), card), isNull);
  });

  test('a flick against the drag direction does not commit', () {
    final g = dragged(const Offset(-40, 0));
    expect(
      g.release(const Offset(-40, 0), const Offset(1500, 0), card),
      isNull,
    );
  });

  test('axis locks after 40 px', () {
    final g = dragged(const Offset(50, 0));
    expect(g.locked, Axis2.horizontal);
    g.update(const Offset(50, 80));
    expect(g.preview, SwipeDirection.right);
  });

  test('rotation is horizontal only and at most 8 degrees', () {
    expect(GestureEngine.rotation(const Offset(0, 300), 360), 0);
    expect(
      GestureEngine.rotation(const Offset(9999, 0), 360).abs(),
      closeTo(8 * 3.14159 / 180, 0.001),
    );
  });

  test('down drags rubber-band after 60 px', () {
    expect(GestureEngine.displayed(const Offset(0, 50)).dy, 50);
    expect(GestureEngine.displayed(const Offset(0, 160)).dy, lessThan(160));
  });

  group('swipe map', () {
    test('standard map matches the product decision', () {
      const m = SwipeMap.standard;
      expect(m.decisionFor(SwipeDirection.right), Decision.willTry);
      expect(m.decisionFor(SwipeDirection.down), Decision.notNow);
      expect(m.decisionFor(SwipeDirection.up), Decision.watched);
      expect(m.decisionFor(SwipeDirection.left), Decision.notInterested);
    });

    test('assigning swaps so every direction stays unique', () {
      final m = SwipeMap.standard.assign(SwipeDirection.left, Decision.willTry);
      expect(m.decisionFor(SwipeDirection.left), Decision.willTry);
      expect(m.decisionFor(SwipeDirection.right), Decision.notInterested);
      expect(m.byDirection.values.toSet().length, 4);
    });

    test('encode and decode round-trip; garbage falls back to standard', () {
      final m = SwipeMap.standard.mirrored;
      expect(SwipeMap.decode(m.encode()), m);
      expect(
        SwipeMap.decode('left=will_try,right=will_try'),
        SwipeMap.standard,
      );
      expect(SwipeMap.decode('nonsense'), SwipeMap.standard);
    });
  });
}
