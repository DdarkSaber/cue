part of 'settings_screen.dart';

class SwipeSettingsPage extends ConsumerWidget {
  const SwipeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = ref.watch(currentSettingsProvider.select((s) => s.swipeMap));
    void set(SwipeMap m) => ref
        .read(settingsProvider.notifier)
        .change((s) => s.copyWith(swipeMap: m));
    return _Detail(
      title: 'Swipe actions',
      children: [
        const Text(
          'Choose what each swipe does. Arrow keys follow the same map. The four buttons keep their labels, so nothing changes meaning by surprise.',
          style: _body,
        ),
        const SizedBox(height: CueSpace.lg),
        CueGroup(
          children: [
            for (final dir in SwipeDirection.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Swipe ${dir.label.toLowerCase()}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CueColors.textMuted,
                      ),
                    ),
                    DropdownButtonFormField<Decision>(
                      isExpanded: true,
                      initialValue: map.decisionFor(dir),
                      key: ValueKey('${dir.name}-${map.encode()}'),
                      items: [
                        for (final d in Decision.values)
                          DropdownMenuItem(
                            value: d,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: DecisionStyle.of(d).color,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    d.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (d) {
                        if (d != null) set(map.assign(dir, d));
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: CueSpace.sm),
        const Text(
          'Picking an action that another swipe had swaps the two, so every action stays one swipe away.',
          style: TextStyle(fontSize: 13, color: CueColors.textMuted),
        ),
        const SizedBox(height: CueSpace.lg),
        Wrap(
          spacing: CueSpace.md,
          runSpacing: CueSpace.sm,
          children: [
            CueSecondaryButton(
              label: 'Swap left and right',
              onPressed: () => set(map.mirrored),
            ),
            CueSecondaryButton(
              label: 'Reset to standard',
              onPressed: map.isStandard ? null : () => set(SwipeMap.standard),
            ),
          ],
        ),
      ],
    );
  }
}
