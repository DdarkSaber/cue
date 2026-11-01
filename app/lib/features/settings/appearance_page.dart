part of 'settings_screen.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(currentSettingsProvider);
    void change(AppSettings Function(AppSettings) f) =>
        ref.read(settingsProvider.notifier).change(f);
    return _Detail(
      title: 'Appearance and accessibility',
      children: [
        _toggle(
          title: 'Reduce motion',
          subtitle: 'No card rotation or fly-out; quick fades instead. Your system setting always applies too.',
          value: s.reduceMotion,
          onChanged: (v) => change((x) => x.copyWith(reduceMotion: v)),
        ),
        _toggle(
          title: 'Haptics',
          subtitle: 'One light tick when a swipe will commit.',
          value: s.haptics,
          onChanged: (v) => change((x) => x.copyWith(haptics: v)),
        ),
        const SizedBox(height: CueSpace.md),
        const Text(
          'Cue follows your device text size and screen reader. Every swipe also has a button, an arrow key and a screen-reader action.',
          style: _body,
        ),
      ],
    );
  }
}
