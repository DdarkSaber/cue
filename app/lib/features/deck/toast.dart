import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/layout.dart';
import '../../app/tokens.dart';
import '../../domain/models/decision.dart';
import 'decision_style.dart';

String toastText(Decision d, {required bool reading}) => switch (d) {
  Decision.willTry => 'Saved to Will try',
  Decision.notNow => 'Hidden for 14 days',
  Decision.watched => reading ? 'Marked as read' : 'Marked as watched',
  Decision.notInterested => 'Not interested. Restore it in Library.',
};

class ToastMessage {
  const ToastMessage(this.text, {this.decision, this.id = 0});
  final String text;
  final Decision? decision;
  final int id;
}

/// Dark glass pill with the action's colour dot. Sits above the card's
/// drag area and never blocks a swipe. Announced to screen readers.
class DeckToast extends StatefulWidget {
  const DeckToast({super.key, required this.message});
  final ToastMessage? message;

  @override
  State<DeckToast> createState() => _DeckToastState();
}

class _DeckToastState extends State<DeckToast> {
  ToastMessage? _shown;
  Timer? _timer;

  @override
  void didUpdateWidget(DeckToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    final m = widget.message;
    if (m != null && m.id != oldWidget.message?.id) {
      _timer?.cancel();
      setState(() => _shown = m);
      _timer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _shown = null);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _shown;
    final reduce = context.reduceMotion;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
        switchInCurve: const Cubic(0.2, 0.8, 0.2, 1),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: reduce
              ? child
              : SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
        ),
        child: m == null
            ? const SizedBox.shrink()
            : Semantics(
                key: ValueKey(m.id),
                liveRegion: true,
                container: true,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: CueColors.toast,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CueColors.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 10,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: m.decision == null
                                  ? CueColors.accent
                                  : DecisionStyle.of(m.decision!).color,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              m.text,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFEEF2F6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
