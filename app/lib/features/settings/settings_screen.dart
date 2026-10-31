import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/route_scaffold.dart';
import '../../app/router.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../domain/models/decision.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/title.dart';
import '../deck/decision_style.dart';

/// Settings: a real page of sections, each with its own detail route.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(currentSettingsProvider);
    void open(String section) => context.go('${CueRoutes.settings}/$section');
    return RouteScaffold(
      kicker: 'Make yourself at home',
      title: 'Settings',
      children: [
        CueGroup(
          children: [
            CueListRow(
              title: 'This library',
              subtitle: s.displayName ?? 'Local to this device',
              onTap: () => open('library'),
            ),
            CueListRow(
              title: 'Library and imports',
              subtitle: 'Import history, past imports',
              onTap: () => context.go(CueRoutes.importer),
            ),
            CueListRow(
              title: 'Recommendation preferences',
              subtitle: 'Region ${s.region}, formats, content safety',
              onTap: () => open('preferences'),
            ),
            CueListRow(
              title: 'Swipe actions',
              subtitle: s.swipeMap.isStandard ? 'Standard' : 'Customised',
              onTap: () => open('swipes'),
            ),
            CueListRow(
              title: 'Appearance and accessibility',
              subtitle: [
                s.reduceMotion ? 'Less motion' : 'Full motion',
                s.haptics ? 'haptics on' : 'haptics off',
              ].join(', '),
              onTap: () => open('appearance'),
            ),
            CueListRow(
              title: 'Sync between devices',
              subtitle: 'Optional, end-to-end encrypted',
              onTap: () => open('sync'),
            ),
            CueListRow(
              title: 'Privacy and data',
              subtitle: 'What leaves the device, export, delete',
              onTap: () => open('privacy'),
            ),
            CueListRow(
              title: 'About Cue',
              subtitle: 'Credits, licences, help',
              onTap: () => open('about'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shared frame for settings detail pages.
class _Detail extends StatelessWidget {
  const _Detail({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => RouteScaffold(
    kicker: 'Settings',
    title: title,
    onBack: () => context.go(CueRoutes.settings),
    children: children,
  );
}

Widget _toggle({
  required String title,
  required String subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) => SwitchListTile(
  contentPadding: EdgeInsets.zero,
  title: Text(title, style: const TextStyle(fontSize: 15)),
  subtitle: Text(
    subtitle,
    style: const TextStyle(fontSize: 13, color: CueColors.textMuted),
  ),
  value: value,
  onChanged: onChanged,
  activeThumbColor: CueColors.onActionPrimary,
  activeTrackColor: CueColors.actionPrimary,
);

const _body = TextStyle(fontSize: 14, height: 1.55, color: CueColors.textMuted);

// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------

class PreferencesPage extends ConsumerWidget {
  const PreferencesPage({super.key});

  static const regions = {
    'IN': 'India',
    'US': 'United States',
    'GB': 'United Kingdom',
    'CA': 'Canada',
    'AU': 'Australia',
    'JP': 'Japan',
    'KR': 'South Korea',
    'SG': 'Singapore',
    'AE': 'United Arab Emirates',
    'DE': 'Germany',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(currentSettingsProvider);
    void change(AppSettings Function(AppSettings) f) =>
        ref.read(settingsProvider.notifier).change(f);
    return _Detail(
      title: 'Recommendation preferences',
      children: [
        const CueSectionLabel('Region for where to watch'),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: regions.containsKey(s.region) ? s.region : 'IN',
          items: [
            for (final e in regions.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => change((x) => x.copyWith(region: v)),
        ),
        const SizedBox(height: 6),
        const Text(
          'You choose this. Cue never asks for your location.',
          style: TextStyle(fontSize: 13, color: CueColors.textMuted),
        ),
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
        _toggle(
          title: 'Include rewatches by default',
          subtitle: 'Titles you rated Rewatched or Would rewatch, and ones watched 3+ years ago',
          value: s.includeRewatches,
          onChanged: (v) => change((x) => x.copyWith(includeRewatches: v)),
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

// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------

class PrivacyPage extends ConsumerStatefulWidget {
  const PrivacyPage({super.key});

  @override
  ConsumerState<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends ConsumerState<PrivacyPage> {
  String? _message;

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
          'Imports read files on this device. Matching sends title names. Sign-in imports open the service\'s own page, read your list once and keep no login. If you turn on sync, only an encrypted blob leaves the device.',
          style: _body,
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

// ---------------------------------------------------------------------------

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _Detail(
      title: 'About Cue',
      children: [
        const Text(
          'Cue: your next story. A free, non-commercial app for deciding what to watch or read next. Name and icon are proposals, not trademark-cleared.',
          style: _body,
        ),
        const CueSectionLabel('Credits'),
        const Text(
          'Anime, manga, manhwa and manhua data and artwork from AniList.\n'
          'Movie titles, ratings and posters from Stremio Cinemeta (an unofficial source).\n'
          'Show artwork and details from TVmaze, used under CC BY-SA.\n'
          'DM Sans by Colophon Foundry, under the SIL Open Font License.',
          style: _body,
        ),
        const CueSectionLabel('How recommendations work'),
        const Text(
          'Rules, not a black box: hard filters first (things you hid, saw or saved never reappear), then a score from tags you rated well, the mood you picked, catalog quality, freshness and a little exploration. Moods are fixed tag sets; your taste comes from your own ratings and swipes. Each reason line states a real signal.',
          style: _body,
        ),
        const SizedBox(height: CueSpace.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: CueSecondaryButton(
            label: 'Open-source licences',
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Cue',
              applicationLegalese: 'Free and non-commercial.',
            ),
          ),
        ),
      ],
    );
  }
}
