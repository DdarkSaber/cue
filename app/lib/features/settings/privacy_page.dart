part of 'settings_screen.dart';

class PrivacyPage extends ConsumerStatefulWidget {
  const PrivacyPage({super.key});

  @override
  ConsumerState<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends ConsumerState<PrivacyPage> {
  String? _message;

  Future<void> _clearMood() async {
    final id = await ref.read(profileIdProvider.future);
    try {
      (await ref.read(moodEngineProvider.future)).forget();
    } on Object {
      // No engine yet: nothing in memory to drop.
    }
    await ref.read(moodRepositoryProvider).clear(id);
    ref.invalidate(moodEngineProvider);
    if (mounted) setState(() => _message = 'Mood learning cleared.');
  }

  Future<void> _export() async {
    final id = await ref.read(profileIdProvider.future);
    final json = await ref.read(backupServiceProvider).export(id);
    final day = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final saved = await FilePicker.saveFile(
        fileName: 'cue-backup-$day.json',
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
      );
      if (!mounted) return;
      setState(
        () => _message = saved == null ? 'Export cancelled.' : 'Exported. The file holds your private history; keep it somewhere safe.',
      );
    } on Object {
      if (mounted) {
        setState(() => _message = 'Could not save the file on this device.');
      }
    }
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: 'Delete this library?',
      body: 'This removes your history, decisions, imports, Will try list and taste data from this device. It cannot be undone. Export first if you may want it back.',
      confirmLabel: 'Delete library',
    );
    if (!ok) return;
    final repo = ref.read(profileRepositoryProvider);
    final id = await ref.read(profileIdProvider.future);
    await repo.deleteProfile(id);
    await repo.ensureActive();
    resetLibraryState(ref);
    if (mounted) {
      setState(
        () => _message = 'Library deleted. A fresh, empty one is ready.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Detail(
      title: 'Privacy and data',
      children: [
        const CueSectionLabel('What stays on this device'),
        const Text(
          'Your history, ratings, decisions, Will try list and taste weights. There is no Cue account and no analytics, ads or trackers.',
          style: _body,
        ),
        const CueSectionLabel('What leaves the device'),
        const Text(
          'Anime, manga, manhwa and manhua lookups go straight from this device to AniList (it does not accept requests through Cloudflare). Dramas, series and movies go through the Cue Worker to TVmaze or Stremio Cinemeta. Lookups include title names or catalog ids, never your history. AniList and the poster hosts can see your IP address, like any website you visit.',
          style: _body,
        ),
        const SizedBox(height: CueSpace.sm),
        const Text(
          'Imports read files on this device. Matching sends title names. Sign-in imports open the service\'s own page, keep a read-only sign-in on this device and renew it when it expires (Sign out removes it). On the web the sign-in sits in this browser\'s storage and the renewal token only lasts until the tab closes, so use Sign out on shared computers. If you turn on sync, only an encrypted blob leaves the device.',
          style: _body,
        ),
        const SizedBox(height: CueSpace.sm),
        const Text(
          'Mood learning (what your words and swipes mean to you) stays on this device. The optional smarter mood text, when turned on, sends only the sentence you type.',
          style: _body,
        ),
        const SizedBox(height: CueSpace.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: CueSecondaryButton(
            label: 'Clear mood learning',
            onPressed: _clearMood,
          ),
        ),
        const CueSectionLabel('Local is not the same as encrypted'),
        const Text(
          'Anyone with access to this device or browser profile can read the library. Clearing browser data can erase it on the web, so export a backup now and then.',
          style: _body,
        ),
        const SizedBox(height: CueSpace.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: CuePrimaryButton(
            label: 'Export my library',
            onPressed: _export,
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: CueSpace.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              _message!,
              style: const TextStyle(fontSize: 14, color: Color(0xFFC1DEF7)),
            ),
          ),
        ],
        const SizedBox(height: CueSpace.xxl),
        const Divider(color: CueColors.line),
        const CueSectionLabel('Delete'),
        Align(
          alignment: Alignment.centerLeft,
          child: CueSecondaryButton(
            label: 'Delete this library',
            destructive: true,
            onPressed: _delete,
          ),
        ),
      ],
    );
  }
}
