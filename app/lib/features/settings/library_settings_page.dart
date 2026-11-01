part of 'settings_screen.dart';

class LibrarySettingsPage extends ConsumerStatefulWidget {
  const LibrarySettingsPage({super.key});

  @override
  ConsumerState<LibrarySettingsPage> createState() =>
      _LibrarySettingsPageState();
}

class _LibrarySettingsPageState extends ConsumerState<LibrarySettingsPage> {
  final _name = TextEditingController();
  String? _editingProfile;
  bool _nameDirty = false;
  bool _savingName = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (_savingName) return;
    final profile = _editingProfile;
    final name = _name.text.trim();
    FocusScope.of(context).unfocus();
    setState(() => _savingName = true);
    try {
      await ref
          .read(settingsProvider.notifier)
          .change(
            (s) => s.copyWith(
              displayName: name.isEmpty ? null : name,
              clearDisplayName: name.isEmpty,
            ),
          );
      if (!mounted || profile != _editingProfile) return;
      _nameDirty = false;
      ref.invalidate(_profilesProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Library name saved.')));
    } on Object catch (error) {
      debugPrint('Library rename failed (${error.runtimeType}).');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the library name. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
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
    final settings = ref.watch(settingsProvider);
    if (_editingProfile != active) {
      _editingProfile = active;
      _nameDirty = false;
      _name.clear();
    }
    final loaded = settings.asData?.value;
    if (!_nameDirty && !settings.isLoading && loaded != null) {
      final name = loaded.displayName ?? '';
      if (_name.text != name) _name.text = name;
    }
    final canName =
        active != null &&
        !settings.isLoading &&
        !settings.hasError &&
        !_savingName;
    return _Detail(
      title: 'This library',
      children: [
        const Text(
          'Lives only on this device. No account is needed.',
          style: _body,
        ),
        const _LibraryContents(),
        const CueSectionLabel('Name (optional)'),
        Row(
          spacing: CueSpace.sm,
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                enabled: canName,
                onChanged: (_) => _nameDirty = true,
                textInputAction: TextInputAction.done,
                onSubmitted: canName ? (_) => _saveName() : null,
                maxLength: 40,
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'My library',
                ),
              ),
            ),
            CueSecondaryButton(
              label: _savingName ? 'Saving...' : 'Save',
              onPressed: canName ? _saveName : null,
            ),
          ],
        ),
        const CueSectionLabel('Libraries on this device'),
        profiles.when(
          loading: () => const LinearProgressIndicator(color: CueColors.accent),
          error: (_, _) => const Text(
            'The libraries on this device could not be read.',
            style: _body,
          ),
          data: (list) => CueGroup(
            children: [
              for (final p in list)
                CueListRow(
                  title: _libraryName(p),
                  subtitle: p.id == active
                      ? 'In use - view contents'
                      : 'View contents',
                  onTap: () => context.go(CueRoutes.libraryContents(p.id)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Delete ${_libraryName(p)}',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteLocalLibrary(context, ref, p),
                      ),
                      const CueIcon(
                        CueIcons.arrow,
                        size: 16,
                        color: CueColors.textMuted,
                      ),
                    ],
                  ),
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
  ref.watch(settingsProvider);
  return ref.read(profileRepositoryProvider).all();
});

String _libraryName(Profile profile) =>
    profile.displayName ??
    'Library from ${profile.createdAt.toLocal().toString().substring(0, 10)}';

Future<bool> _deleteLocalLibrary(
  BuildContext context,
  WidgetRef ref,
  Profile profile, {
  String? confirmationTitle,
  bool returnToLibraries = true,
}) async {
  if (!context.mounted) return false;
  final ok = await confirmAction(
    context,
    title: confirmationTitle ?? 'Delete ${_libraryName(profile)}?',
    body: 'This deletes only this library from this device, including its titles, imports, swipes and mood learning. Other libraries stay. It cannot be undone; export first if you may need it back. Any encrypted sync copy on the server is not deleted.',
    confirmLabel: 'Delete library',
  );
  if (!ok || !context.mounted) return false;
  try {
    final repo = ref.read(profileRepositoryProvider);
    final active = await ref.read(profileIdProvider.future);
    await ref.read(codeStoreProvider).delete(profile.id);
    await repo.deleteProfile(profile.id);
    final next = await repo.ensureActive();
    if (active == profile.id) {
      await repo.activate(next.id);
      resetLibraryState(ref);
    } else {
      ref.read(libraryVersionProvider.notifier).bump();
    }
    ref.invalidate(_profilesProvider);
    if (context.mounted) {
      if (returnToLibraries) context.go('${CueRoutes.settings}/library');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Library deleted from this device.')),
      );
    }
    return true;
  } on Object catch (error) {
    debugPrint('Library deletion failed (${error.runtimeType}).');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this library. Try again.'),
        ),
      );
    }
    return false;
  }
}

/// After switching, creating or deleting a library, everything personal
/// reloads from the new active profile.
void resetLibraryState(WidgetRef ref) {
  ref.invalidate(profileIdProvider);
  ref.invalidate(settingsProvider);
  ref.read(libraryVersionProvider.notifier).bump();
}
