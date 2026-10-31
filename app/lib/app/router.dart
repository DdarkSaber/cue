import 'package:go_router/go_router.dart';

import '../features/deck/deck_screen.dart';
import '../features/imports/import_screen.dart';
import '../features/library/library_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shortlist/shortlist_screen.dart';
import 'shell.dart';

abstract final class CueRoutes {
  static const forYou = '/';
  static const willTry = '/will-try';
  static const library = '/library';
  static const settings = '/settings';
  static const importer = '/library/import';
}

GoRouter buildRouter({String initialLocation = CueRoutes.forYou}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: CueRoutes.forYou,
              builder: (_, _) => const DeckScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: CueRoutes.willTry,
              builder: (_, _) => const ShortlistScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: CueRoutes.library,
              builder: (_, _) => const LibraryScreen(),
              routes: [
                GoRoute(
                  path: 'import',
                  builder: (_, _) => const ImportScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: CueRoutes.settings,
              builder: (_, _) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
