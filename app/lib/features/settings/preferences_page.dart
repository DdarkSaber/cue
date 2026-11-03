part of 'settings_screen.dart';

class PreferencesPage extends ConsumerWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(currentSettingsProvider);
    void change(AppSettings Function(AppSettings) f) =>
        ref.read(settingsProvider.notifier).change(f);
    return _Detail(
      title: 'Recommendation preferences',
      children: [
        const CueSectionLabel('Formats in your deck'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final k in MediaKind.discoverable)
              CueChoiceChip(
                label: k.label,
                selected: s.defaultKinds.contains(k),
                onTap: () {
                  final next = {...s.defaultKinds};
                  next.contains(k) ? next.remove(k) : next.add(k);
                  if (next.isEmpty) return;
                  change((x) => x.copyWith(defaultKinds: next));
                },
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Dramas and series come from TVmaze and movies from Stremio Cinemeta, so nothing needs a key or an account.',
          style: TextStyle(fontSize: 13, color: CueColors.textMuted),
        ),
        const SizedBox(height: CueSpace.md),
        const Text(
          'New suggestions exclude every title in this library, including planned titles. Choose Revisit on the deck for titles marked to rewatch, or watched 3+ years ago.',
          style: TextStyle(fontSize: 13, color: CueColors.textMuted),
        ),
        const CueSectionLabel('Live mood'),
        const FranchiseExclusionsSection(),
        _toggle(
          title: 'Smarter mood text',
          subtitle: 'Off by default. When on, the sentence you type in Tell me is sent to an AI service (Groq or Google Gemini) to suggest genres. Nothing else is sent. Mood learning itself always stays on this device.',
          value: s.smartMoodText,
          onChanged: (v) => change((x) => x.copyWith(smartMoodText: v)),
        ),
        _toggle(
          title: 'AI picks from my taste',
          subtitle: 'Off by default. When on, the names (and years) of up to 25 titles you rated highly, saved or finished, and up to 10 you disliked, plus your enabled formats, are sent to an AI service (Groq or Google Gemini) to suggest more. Suggestions are checked against the real catalog. Ratings, notes and dates never leave this device.',
          value: s.aiPicks,
          onChanged: (v) =>
              change((x) => x.copyWith(aiPicks: v, aiPicksPromptSeen: true)),
        ),
        const CueSectionLabel('Content safety'),
        _toggle(
          title: 'Show adult-tagged titles',
          subtitle:
              'Off by default. Explicit titles are never fetched either way.',
          value: s.showAdult,
          onChanged: (v) async {
            if (v) {
              final ok = await confirmAction(
                context,
                title: 'Show adult-tagged titles?',
                body: 'Titles tagged for mature content (for example some manhwa) will appear in this library\'s deck. You can turn this off at any time.',
                confirmLabel: 'Show them',
                destructive: false,
              );
              if (!ok) return;
            }
            change((x) => x.copyWith(showAdult: v));
          },
        ),
      ],
    );
  }
}
