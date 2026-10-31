import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/quick_mood.dart';

class SelectedMood extends Notifier<QuickMood> {
  @override
  QuickMood build() => QuickMood.forYou;

  void select(QuickMood mood) => state = mood;
}

final selectedMoodProvider = NotifierProvider<SelectedMood, QuickMood>(
  SelectedMood.new,
);

/// Whether there is a decision to undo. Decisions arrive in M2; until then
/// nothing can be undone, so the phone header hides the undo icon.
final canUndoProvider = Provider<bool>((ref) => false);

/// Whether the deck has a card to act on. The catalog arrives in M1.
final hasCardProvider = Provider<bool>((ref) => false);
