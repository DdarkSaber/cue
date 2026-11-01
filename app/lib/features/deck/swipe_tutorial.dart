import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/decision.dart';

/// Off in widget tests, which would otherwise all open on this dialog.
final swipeTutorialEnabledProvider = Provider<bool>((ref) => true);

const _doneKey = 'tutorialDone';

/// Shows the four swipe directions once, using the person's own mapping.
Future<void> maybeShowSwipeTutorial(BuildContext context, WidgetRef ref) async {
  if (!ref.read(swipeTutorialEnabledProvider)) return;
  final profileId = await ref.read(profileIdProvider.future);
  final profiles = ref.read(profileRepositoryProvider);
  if (await profiles.rawSetting(profileId, _doneKey) == 'true') return;
  if (!context.mounted) return;
  final map = ref.read(currentSettingsProvider).swipeMap;
  String line(SwipeDirection d, String arrow) =>
      '$arrow  ${map.decisionFor(d).label}';
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('How to swipe'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in [
            line(SwipeDirection.right, '→'),
            line(SwipeDirection.left, '←'),
            line(SwipeDirection.up, '↑'),
            line(SwipeDirection.down, '↓'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(t, style: const TextStyle(fontSize: 16)),
            ),
          const SizedBox(height: 8),
          const Text(
            'The buttons and arrow keys do the same, and Undo always works. Change directions in Settings, Swipe actions.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
  await profiles.setRawSetting(profileId, _doneKey, 'true');
}
