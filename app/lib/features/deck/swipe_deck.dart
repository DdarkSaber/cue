import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../app/icons.dart';
import '../../app/layout.dart';
import '../../app/tokens.dart';
import '../../domain/models/decision.dart';
import '../../domain/ranker.dart';
import 'decision_style.dart';
import 'gesture_engine.dart';
import 'story_card.dart';

/// The top card plus the next one peeking below, with the swipe gesture.
/// Decisions are reported as directions; the swipe map turns them into
/// decisions. Other decks (rating your library) pass [choices] instead, so
/// they share the same gesture, stamps, haptics and reduced motion.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.cards,
    this.swipeMap = SwipeMap.standard,
    required this.onSwipe,
    required this.onDetails,
    this.enabled = true,
    this.reduceMotion = false,
    this.haptics = true,
    this.onTryNow,
    this.onPosterHold,
    this.choices,
    this.cardLabel = 'Recommendation',
  });

  final List<RankedCard> cards;
  final SwipeMap swipeMap;

  /// When set, what each direction means instead of the swipe map's
  /// decisions: drives the stamp and the screen-reader actions.
  final Map<SwipeDirection, SwipeChoice>? choices;

  /// Screen-reader prefix before the card's title.
  final String cardLabel;
  final void Function(SwipeDirection) onSwipe;
  final VoidCallback onDetails;
  final bool enabled;
  final bool reduceMotion;
  final bool haptics;
  final void Function(String titleId)? onTryNow;

  /// The top card was held to see its whole poster.
  final void Function(String titleId)? onPosterHold;

  @override
  State<SwipeDeck> createState() => SwipeDeckState();
}

class SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  final _engine = GestureEngine();
  late final AnimationController _anim = AnimationController.unbounded(
    vsync: this,
  );
  Offset _offset = Offset.zero;
  double _fade = 1;
  bool _dragging = false;
  bool _ignoring = false;
  bool _pastThreshold = false;
  bool _exiting = false;
  int _pointers = 0;
  Size _card = Size.zero;

  bool get _reduce => widget.reduceMotion || context.reduceMotion;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _dragging) _cancel();
  }

  void _onPanStart(DragStartDetails d) {
    if (!widget.enabled || _exiting || widget.cards.isEmpty) return;
    final width = MediaQuery.sizeOf(context).width;
    final x = d.globalPosition.dx;
    // Leave the OS back-gesture edges to the system.
    _ignoring =
        x < CueMotion.backEdgeInset || x > width - CueMotion.backEdgeInset;
    if (_ignoring) return;
    _anim.stop();
    _engine.start();
    _dragging = true;
    _pastThreshold = false;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_dragging || _ignoring) return;
    if (_pointers > 1) return _cancel();
    // Follow the finger exactly: no easing while it is down.
    final next = _offset + d.delta;
    _engine.update(next);
    final crossed = _engine.progress(next, _card) >= 1;
    if (crossed && !_pastThreshold && widget.haptics) {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _offset = next;
      _pastThreshold = crossed;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_dragging || _ignoring) return;
    _dragging = false;
    final dir = _engine.release(_offset, d.velocity.pixelsPerSecond, _card);
    if (dir == null) {
      _settle(d.velocity.pixelsPerSecond);
    } else {
      _exit(dir, d.velocity.pixelsPerSecond);
    }
  }

  void _cancel() {
    _dragging = false;
    _settle(Offset.zero);
  }

  /// Spring back to rest using the release velocity (220 to 320 ms).
  void _settle(Offset velocity) {
    _engine.reset();
    final start = _offset;
    if (start == Offset.zero) return setState(() {});
    final distance = start.distance;
    final speed = velocity.distance;
    final spring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 420,
      ratio: 0.86,
    );
    _anim.value = 0;
    void tick() => setState(() => _offset = start * (1 - _anim.value));
    _anim.addListener(tick);
    _anim
        .animateWith(
          SpringSimulation(spring, 0, 1, distance == 0 ? 0 : speed / distance),
        )
        .whenCompleteOrCancel(() {
          _anim.removeListener(tick);
          if (mounted) setState(() => _offset = Offset.zero);
        });
  }

  /// Leaves the screen in the chosen direction (180 to 240 ms), then reports.
  Future<void> _exit(SwipeDirection dir, Offset velocity) async {
    if (_exiting) return;
    _exiting = true;
    _engine.reset();
    // A firmer tick when the choice lands, whether swiped or tapped.
    if (widget.haptics) unawaited(HapticFeedback.mediumImpact());
    final screen = MediaQuery.sizeOf(context);
    if (_reduce) {
      // Cross-fade only: no rotation, no fly-out.
      _anim.value = 0;
      void tick() => setState(() => _fade = 1 - _anim.value);
      _anim.addListener(tick);
      await _anim
          .animateTo(1, duration: const Duration(milliseconds: 140))
          .orCancel
          .catchError((_) {});
      _anim.removeListener(tick);
    } else {
      final start = _offset;
      final end = GestureEngine.exitOffset(dir, screen);
      final speed = velocity.distance;
      final ms = speed > 1500
          ? CueMotion.exitMin.inMilliseconds
          : CueMotion.exitMax.inMilliseconds;
      _anim.value = 0;
      void tick() => setState(
        () => _offset = Offset.lerp(
          start,
          end,
          Curves.easeOut.transform(_anim.value.clamp(0, 1)),
        )!,
      );
      _anim.addListener(tick);
      await _anim
          .animateTo(1, duration: Duration(milliseconds: ms))
          .orCancel
          .catchError((_) {});
      _anim.removeListener(tick);
    }
    if (!mounted) return;
    widget.onSwipe(dir);
    setState(() {
      _offset = Offset.zero;
      _fade = 1;
      _exiting = false;
    });
  }

  /// Buttons, keys and screen-reader actions animate the same way.
  Future<void> swipe(SwipeDirection dir) async {
    if (widget.cards.isEmpty || _exiting) return;
    _anim.stop();
    if (!_reduce) {
      // A short lean in the direction before leaving reads as the same move.
      _engine.start();
      _engine.update(GestureEngine.exitOffset(dir, const Size(60, 60)));
    }
    await _exit(dir, Offset.zero);
  }

  /// Undo: the card returns from the side it left (180 to 240 ms).
  Future<void> bringBack(SwipeDirection from) async {
    final screen = MediaQuery.sizeOf(context);
    _anim.stop();
    if (_reduce) {
      _anim.value = 0;
      void tick() => setState(() => _fade = _anim.value);
      _anim.addListener(tick);
      await _anim
          .animateTo(1, duration: const Duration(milliseconds: 140))
          .orCancel
          .catchError((_) {});
      _anim.removeListener(tick);
      return;
    }
    final start = GestureEngine.exitOffset(from, screen);
    _anim.value = 0;
    void tick() => setState(
      () => _offset = Offset.lerp(
        start,
        Offset.zero,
        Curves.easeOutCubic.transform(_anim.value.clamp(0, 1)),
      )!,
    );
    _anim.addListener(tick);
    setState(() => _offset = start);
    await _anim
        .animateTo(1, duration: CueMotion.exitMax)
        .orCancel
        .catchError((_) {});
    _anim.removeListener(tick);
    if (mounted) setState(() => _offset = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final desktop = context.cueLayout == CueLayout.desktop;
    final radius = desktop ? CueRadius.cardDesktop : CueRadius.cardPhone;
    final top = widget.cards.isEmpty ? null : widget.cards.first;
    final next = widget.cards.length > 1 ? widget.cards[1] : null;
    final topTitleId = top?.title.id;
    final tryNow = widget.onTryNow;

    return LayoutBuilder(
      builder: (context, c) {
        _card = Size(c.maxWidth, c.maxHeight);
        final shown = GestureEngine.displayed(_offset);
        final progress = _engine.progress(_offset, _card);
        final dragAmount = min(_offset.distance / 120, 1.0);
        final nextScale =
            CueMotion.nextCardScale +
            (1 - CueMotion.nextCardScale) * (_exiting ? 1 : dragAmount);
        final preview = _engine.preview;

        return Listener(
          onPointerDown: (_) => _pointers++,
          onPointerUp: (_) => _pointers = max(0, _pointers - 1),
          onPointerCancel: (_) => _pointers = max(0, _pointers - 1),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(0, 7 * (1 - dragAmount)),
                child: Transform.scale(
                  scale: nextScale,
                  child: next == null
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2027),
                            borderRadius: BorderRadius.circular(radius),
                            border: Border.all(color: const Color(0x14FFFFFF)),
                          ),
                        )
                      : ExcludeSemantics(
                          child: IgnorePointer(
                            child: StoryCard(
                              key: ValueKey('next-${next.title.id}'),
                              title: next.title,
                              reason: next.reason,
                            ),
                          ),
                        ),
                ),
              ),
              if (top != null)
                GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  onPanCancel: () {
                    if (_dragging) _cancel();
                  },
                  child: Opacity(
                    opacity: _fade,
                    child: Transform.translate(
                      offset: shown,
                      child: Transform.rotate(
                        angle: _reduce
                            ? 0
                            : GestureEngine.rotation(shown, _card.width),
                        alignment: const Alignment(0, 0.3),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RepaintBoundary(
                              child: _CardSemantics(
                                card: top,
                                swipeMap: widget.swipeMap,
                                choices: widget.choices,
                                cardLabel: widget.cardLabel,
                                onSwipe: swipe,
                                onDetails: widget.onDetails,
                                onTryNow: widget.onTryNow == null
                                    ? null
                                    : () => tryNow!(topTitleId!),
                                child: GestureDetector(
                                  key: ValueKey(
                                    'story-card-actions-${top.title.id}',
                                  ),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: tryNow == null
                                      ? null
                                      : widget.onDetails,
                                  onDoubleTap: tryNow == null
                                      ? null
                                      : () => tryNow(topTitleId!),
                                  child: StoryCard(
                                    key: ValueKey('top-${top.title.id}'),
                                    title: top.title,
                                    reason: top.reason,
                                    onDetails: widget.onDetails,
                                    onHold: widget.onPosterHold == null
                                        ? null
                                        : () => widget.onPosterHold!(
                                            top.title.id,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            if (preview != null && progress > 0)
                              _Stamp(
                                choice:
                                    widget.choices?[preview] ??
                                    SwipeChoice.decision(
                                      widget.swipeMap.decisionFor(preview),
                                      reading: top.title.kind.isReading,
                                    ),
                                direction: preview,
                                opacity: Curves.easeOut.transform(
                                  (progress * 1.3).clamp(0, 1),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Screen-reader actions on the card, one per decision plus details.
class _CardSemantics extends StatelessWidget {
  const _CardSemantics({
    required this.card,
    required this.swipeMap,
    required this.choices,
    required this.cardLabel,
    required this.onSwipe,
    required this.onDetails,
    required this.onTryNow,
    required this.child,
  });

  final RankedCard card;
  final SwipeMap swipeMap;
  final Map<SwipeDirection, SwipeChoice>? choices;
  final String cardLabel;
  final Future<void> Function(SwipeDirection) onSwipe;
  final VoidCallback onDetails;
  final VoidCallback? onTryNow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reading = card.title.kind.isReading;
    final tryNowActions = onTryNow == null
        ? null
        : <CustomSemanticsAction, VoidCallback>{
            const CustomSemanticsAction(label: 'Try now'): onTryNow!,
          };
    final choices = this.choices;
    return Semantics(
      container: true,
      label: '$cardLabel: ${card.title.displayTitle}. ${card.reason}',
      customSemanticsActions: {
        if (choices != null)
          for (final MapEntry(key: dir, value: choice) in choices.entries)
            CustomSemanticsAction(label: choice.label): () => onSwipe(dir)
        else
          for (final d in Decision.values)
            CustomSemanticsAction(label: d.labelFor(reading: reading)): () =>
                onSwipe(swipeMap.directionFor(d)),
        ...?tryNowActions,
        const CustomSemanticsAction(label: 'Open details'): onDetails,
      },
      child: child,
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.choice,
    required this.direction,
    required this.opacity,
  });

  final SwipeChoice choice;
  final SwipeDirection direction;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final style = choice.style;
    final align = switch (direction) {
      SwipeDirection.right => const Alignment(-0.8, -0.72),
      SwipeDirection.left => const Alignment(0.8, -0.72),
      SwipeDirection.up => const Alignment(0, 0.35),
      SwipeDirection.down => const Alignment(0, -0.6),
    };
    return IgnorePointer(
      child: Align(
        alignment: align,
        child: Opacity(
          opacity: opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: style.stampBackground,
              borderRadius: BorderRadius.circular(7),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 25,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                CueIcon(
                  style.icon,
                  size: 18,
                  color: style.stampText,
                  strokeWidth: 2,
                ),
                Text(
                  choice.label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: style.stampText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
