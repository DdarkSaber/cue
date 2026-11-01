part of 'settings_screen.dart';

class LibrarySettingsPage extends ConsumerStatefulWidget {
  const LibrarySettingsPage({super.key});

  @override
  ConsumerState<LibrarySettingsPage> createState() =>
      _LibrarySettingsPageState();
}

class _LibrarySettingsPageState extends ConsumerState<LibrarySettingsPage> {
  late final _name = TextEditingController(
    text: ref.read(currentSettingsProvider).displayName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _fresh() async {
    final ok = await confirmAction(
      context,
      title: 'Start a fresh library?',
      body: 'Your current library stays on this device and you can switch back. Local libraries are not a security boundary between people.',
      confirmLabel: 'Start fresh',
      destructive: false,
    );
    if (!ok) return;
    await ref.read(profileRepositoryProvider).create();
    resetLibraryState(ref);
  }

  Future<void> _resetSwipes() async {
    final ok = await confirmAction(
      context,
      title: 'Reset your swipes?',
      body: 'Will try, Not interested, Not now and mood learning are cleared. Imported and rated titles stay.',
      confirmLabel: 'Reset swipes',
    );
    if (!ok) return;
    final id = await ref.read(profileIdProvider.future);
    await ref.read(libraryRepositoryProvider).resetSwipes(id);
    try {
      (await ref.read(moodEngineProvider.future)).forget();
    } on Object {
      // Not loaded yet.
    }
    await ref.read(moodRepositoryProvider).clear(id);
    ref.invalidate(moodEngineProvider);
    ref.read(decisionVersionProvider.notifier).bump();
    ref.read(libraryVersionProvider.notifier).bump();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Swipes reset.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(_profilesProvider);
    final active = ref.watch(profileIdProvider).value;
    return _Detail(
      title: 'This library',
      children: [
        const Text(
          'Lives only on this device. No account is needed.',
          style: _body,
        ),
        const CueSectionLabel('Name (optional)'),
        Row(
          spacing: CueSpace.sm,
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                maxLength: 40,
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'My library',
                ),
              ),
            ),
            CueSecondaryButton(
              label: 'Save',
              onPressed: () => ref
                  .read(settingsProvider.notifier)
                  .change(
                    (s) => s.copyWith(
                      displayName: _name.text.trim().isEmpty
                          ? null
                          : _name.text.trim(),
                    ),
                  ),
            ),
          ],
        ),
        const CueSectionLabel('Libraries on this device'),
        profiles.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (list) => CueGroup(
            children: [
              for (final p in list)
                CueListRow(
                  title:
                      p.displayName ??
                      'Library from ${p.createdAt.toLocal().toString().substring(0, 10)}',
                  subtitle: p.id == active
                      ? 'In use'
                      : 'Switch to this library',
                  onTap: p.id == active
                      ? null
                      : () async {
                          await ref
                              .read(profileRepositoryProvider)
                              .activate(p.id);
                          resetLibraryState(ref);
                        },
                ),
            ],
          ),
        ),
        const SizedBox(height: CueSpace.md),
        Align(
          alignment: Alignment.centerLeft,
          child: CueSecondaryButton(
            label: 'Start a fresh library',
            onPressed: _fresh,
          ),
        ),
        const SizedBox(height: CueSpace.md),
        Align(
          alignment: Alignment.centerLeft,
          child: CueSecondaryButton(
            label: 'Reset swipes',
            destructive: true,
            onPressed: _resetSwipes,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Forgets your deck decisions and mood learning. Imported and rated titles stay. With sync on, your other devices follow.',
          style: TextStyle(fontSize: 13, color: CueColors.textMuted),
        ),
      ],
    );
  }
}

final _profilesProvider = FutureProvider.autoDispose((ref) {
  ref.watch(profileIdProvider);
  return ref.read(profileRepositoryProvider).all();
});

/// After switching, creating or deleting a library, everything personal
/// reloads from the new active profile.
void resetLibraryState(WidgetRef ref) {
  ref.invalidate(profileIdProvider);
  ref.invalidate(settingsProvider);
  ref.read(libraryVersionProvider.notifier).bump();
}
