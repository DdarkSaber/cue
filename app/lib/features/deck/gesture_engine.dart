import 'dart:math';
import 'dart:ui' show Offset, Size;

import '../../app/tokens.dart';
import '../../domain/models/decision.dart';

enum GesturePhase { idle, tracking, preview }

enum Axis2 { horizontal, vertical }

/// Pure swipe logic: preview, axis lock and commit, with the motion numbers
/// from the design tokens. The widget only feeds it pointer data.
class GestureEngine {
  GesturePhase phase = GesturePhase.idle;
  SwipeDirection? preview;
  Axis2? locked;

  void start() {
    phase = GesturePhase.tracking;
    preview = null;
    locked = null;
  }

  void reset() {
    phase = GesturePhase.idle;
    preview = null;
    locked = null;
  }

  static SwipeDirection _dirFor(Axis2 axis, Offset o) =>
      axis == Axis2.horizontal
      ? (o.dx >= 0 ? SwipeDirection.right : SwipeDirection.left)
      : (o.dy >= 0 ? SwipeDirection.down : SwipeDirection.up);

  /// Feeds the total drag offset; updates the previewed direction.
  void update(Offset o) {
    if (phase == GesturePhase.idle) return;
    final ax = o.dx.abs(), ay = o.dy.abs();
    if (locked != null) {
      preview = _dirFor(locked!, o);
      phase = GesturePhase.preview;
      return;
    }
    if (max(ax, ay) < CueMotion.previewDistance) {
      preview = null;
      phase = GesturePhase.tracking;
      return;
    }
    Axis2? axis;
    if (ax >= ay * CueMotion.axisDominance) axis = Axis2.horizontal;
    if (ay >= ax * CueMotion.axisDominance) axis = Axis2.vertical;
    // Hysteresis: an ambiguous diagonal keeps the current preview.
    if (axis != null) {
      preview = _dirFor(axis, o);
      phase = GesturePhase.preview;
      if (max(ax, ay) >= CueMotion.axisLock) locked = axis;
    }
  }

  /// 0..1 progress toward the commit distance in the previewed direction.
  double progress(Offset o, Size card) {
    final p = preview;
    if (p == null) return 0;
    final horizontal = p == SwipeDirection.left || p == SwipeDirection.right;
    final along = horizontal ? o.dx : o.dy;
    final sign = (p == SwipeDirection.right || p == SwipeDirection.down)
        ? 1
        : -1;
    final d = along * sign;
    if (d <= 0) return 0;
    final target = CueMotion.commitDistance(
      horizontal ? card.width : card.height,
    );
    return (d / target).clamp(0, 1).toDouble();
  }

  /// Decides on release. A diagonal with no clear axis cancels; it never
  /// guesses. Velocity alone never commits a tap.
  SwipeDirection? release(Offset o, Offset velocity, Size card) {
    final axis = locked ?? _clearAxis(o);
    if (axis == null) return null;
    final dir = _dirFor(axis, o);
    final horizontal = axis == Axis2.horizontal;
    final d = (horizontal ? o.dx : o.dy).abs();
    final v = horizontal ? velocity.dx : velocity.dy;
    final along = horizontal ? o.dx : o.dy;
    final target = CueMotion.commitDistance(
      horizontal ? card.width : card.height,
    );
    if (d >= target) return dir;
    final sameWay = v.sign == along.sign && along != 0;
    if (v.abs() > CueMotion.flickVelocity &&
        d >= CueMotion.flickMinDistance &&
        sameWay) {
      return dir;
    }
    return null;
  }

  Axis2? _clearAxis(Offset o) {
    final ax = o.dx.abs(), ay = o.dy.abs();
    if (max(ax, ay) < CueMotion.previewDistance) return null;
    if (ax >= ay * CueMotion.axisDominance) return Axis2.horizontal;
    if (ay >= ax * CueMotion.axisDominance) return Axis2.vertical;
    return null;
  }

  /// Down drags rubber-band after 60 px so the card never covers the buttons.
  static Offset displayed(Offset o) {
    const limit = CueMotion.downRubberBandAfter;
    if (o.dy <= limit) return o;
    return Offset(o.dx, limit + (o.dy - limit) * 0.35);
  }

  /// Horizontal rotation only, at most 8 degrees.
  static double rotation(Offset o, double cardWidth) {
    const maxRad = CueMotion.maxRotationDeg * pi / 180;
    return (o.dx / max(cardWidth, 1) * maxRad * 1.6).clamp(-maxRad, maxRad);
  }

  /// Where a card ends up when it leaves in a direction.
  static Offset exitOffset(SwipeDirection d, Size screen) => switch (d) {
    SwipeDirection.right => Offset(screen.width * 1.2, 0),
    SwipeDirection.left => Offset(-screen.width * 1.2, 0),
    SwipeDirection.up => Offset(0, -screen.height * 1.1),
    SwipeDirection.down => Offset(0, screen.height * 1.1),
  };
}
