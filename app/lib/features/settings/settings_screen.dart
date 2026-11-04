import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/icons.dart';
import '../../app/layout.dart';
import '../../app/route_scaffold.dart';
import '../../app/router.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../domain/models/decision.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/title.dart';
import '../../data/db/database.dart';
import '../../data/library_repository.dart';
import '../deck/decision_style.dart';
import '../imports/source_names.dart';
import '../library/review_sheet.dart';
import 'franchise_exclusions_section.dart';

part 'about_page.dart';
part 'appearance_page.dart';
part 'library_contents.dart';
part 'library_contents_page.dart';
part 'library_settings_page.dart';
part 'preferences_page.dart';
part 'privacy_page.dart';
part 'swipe_settings_page.dart';
part 'diagnostics_section.dart';

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
        const CueSectionLabel('Recommendations'),
        CueGroup(
          children: [
            CueListRow(
              title: 'Recommendation preferences',
              subtitle: 'Formats, mood, content safety',
              onTap: () => open('preferences'),
            ),
            CueListRow(
              title: 'AI picks',
              subtitle: s.aiPicks
                  ? 'On. Some title names are sent to an AI service'
                  : 'Off. Nothing is sent to an AI service',
              onTap: () => open('preferences'),
            ),
            CueListRow(
              title: 'Swipe actions',
              subtitle: s.swipeMap.isStandard ? 'Standard' : 'Customised',
              onTap: () => open('swipes'),
            ),
          ],
        ),
        const CueSectionLabel('Appearance'),
        CueGroup(
          children: [
            CueListRow(
              title: 'Appearance and accessibility',
              subtitle: [
                s.reduceMotion ? 'Less motion' : 'Full motion',
                s.haptics ? 'haptics on' : 'haptics off',
              ].join(', '),
              onTap: () => open('appearance'),
            ),
          ],
        ),
        const CueSectionLabel('Library and sync'),
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
              title: 'Sync between devices',
              subtitle: 'Optional, end-to-end encrypted',
              onTap: () => open('sync'),
            ),
          ],
        ),
        const CueSectionLabel('Privacy'),
        CueGroup(
          children: [
            CueListRow(
              title: 'Privacy and data',
              subtitle: 'What leaves the device, export, delete',
              onTap: () => open('privacy'),
            ),
          ],
        ),
        const CueSectionLabel('About'),
        CueGroup(
          children: [
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
