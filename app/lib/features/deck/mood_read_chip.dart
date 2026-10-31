import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sheets.dart';
import '../../app/tokens.dart';
import '../../domain/models/quick_mood.dart';
import '../../domain/mood/mode_model.dart';
import 'deck_controller.dart';

/// "Cue read: Isekai · Fantasy": what the live mood learner thinks you are
/// in the mood for. Tap to correct it; long-press a mode to rename it.
class MoodReadChip extends ConsumerWidget {
  const MoodReadChip({super.key});

  static const showAbove = 0.3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final read = ref.watch(moodReadProvider);
    final forYou = ref.watch(
      deckFiltersProvider.select((f) => f.mood == QuickMood.forYou),
    );
    if (!forYou || read.label == null || read.confidence < showAbove) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: 'Cue read your mood as ${read.label}. Change',
        excludeSemantics: true,
        child: TextButton(
          onPressed: () => _open(context, ref, read.modeId),
          style: TextButton.styleFrom(
            minimumSize: const Size(CueSize.minTarget, CueSize.minTarget),
            foregroundColor: CueColors.textMuted,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Text(
            'Cue read: ${read.label}',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final engine = await ref.read(moodEngineProvider.future);
    if (!context.mounted) return;
    await showCueSheet<void>(
      context,
      kicker: 'Live mood',
      title: 'What are you in the mood for?',
      body: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cue learns these from what you pick. Choose one to steer the deck now. Long-press to rename.',
            style: TextStyle(
              fontSize: 14,
              color: CueColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: CueSpace.md),
          for (final m in engine.modes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(m.label),
              trailing: m.id == current
                  ? const Icon(Icons.check, size: 20)
                  : null,
              onTap: () {
                engine.correct(m.id);
                ref.read(deckControllerProvider.notifier).moodChanged();
                Navigator.of(ctx).pop();
              },
              onLongPress: () => _rename(ctx, ref, m),
            ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Mode m) async {
    final controller = TextEditingController(text: m.label);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename mood'),
        content: TextField(
          controller: controller,
          maxLength: 32,
          autofocus: true,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    final clean = name?.trim() ?? '';
    if (clean.isEmpty) return;
    final engine = await ref.read(moodEngineProvider.future);
    await engine.rename(m.id, clean);
    ref.read(deckControllerProvider.notifier).moodChanged();
  }
}
