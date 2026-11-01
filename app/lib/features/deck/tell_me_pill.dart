import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/text_prompt.dart';
import '../../app/tokens.dart';
import '../../domain/mood_rules.dart';
import 'deck_controller.dart';

/// "Tell me…" at the end of the mood rail: one tap to type what you feel
/// like. Recognised words set filters; every sentence also feeds the live
/// mood learner, which learns what your words mean over time.
class TellMePill extends ConsumerWidget {
  const TellMePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(deckFiltersProvider.select((f) => f.tellMe));
    final has = text != null && text.isNotEmpty;
    return Semantics(
      button: true,
      label: has ? 'Tell me: $text. Change' : 'Tell me what you feel like',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: CueSize.minTarget,
          maxWidth: 220,
        ),
        child: OutlinedButton(
          onPressed: () => _open(context, ref, text ?? ''),
          style: OutlinedButton.styleFrom(
            foregroundColor: has ? CueColors.text : CueColors.textMuted,
            side: const BorderSide(color: CueColors.line),
            shape: const StadiumBorder(),
          ),
          child: Text(
            has ? '“$text”' : 'Tell me…',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final result = await showTextPrompt(
      context,
      title: 'What do you feel like?',
      confirmLabel: 'Show me',
      initial: current,
      hint: 'a short anime grind, a slow rom-com…',
      clearLabel: 'Clear',
    );
    if (result == null) return;
    final text = result.trim();
    final filters = ref.read(deckFiltersProvider);
    final parsed = parseMood(text);
    ref.read(deckFiltersProvider.notifier).apply(parsed.applyTo(filters, text));
    if (text.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(parsed.feedback),
          duration: const Duration(seconds: 12),
        ),
      );
    }
  }
}
