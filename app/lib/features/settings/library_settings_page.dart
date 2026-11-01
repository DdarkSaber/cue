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
