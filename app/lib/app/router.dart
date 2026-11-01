import 'package:go_router/go_router.dart';

import '../features/deck/deck_screen.dart';
import '../features/imports/import_screen.dart' deferred as importer;
import '../features/library/library_screen.dart';
import '../features/settings/settings_screen.dart' deferred as settings;
import '../features/shortlist/shortlist_screen.dart';
import '../features/sync/sync_page.dart' deferred as sync;
import 'deferred_page.dart';
import 'shell.dart';

/// Loads the screens that the web build splits off. Called once at start on
/// Android, where deferred loading saves nothing.
Future<void> preloadDeferred() => Future.wait([
  importer.loadLibrary(),
  settings.loadLibrary(),
  sync.loadLibrary(),
]);

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
                  builder: (_, _) => DeferredPage(
                    importer.loadLibrary,
                    () => importer.ImportScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: CueRoutes.settings,
              builder: (_, _) => DeferredPage(
                settings.loadLibrary,
                () => settings.SettingsScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'library',
                  builder: (_, _) => DeferredPage(
                    settings.loadLibrary,
                    () => settings.LibrarySettingsPage(),
                  ),
                ),
                GoRoute(
                  path: 'preferences',
                  builder: (_, _) => DeferredPage(
                    settings.loadLibrary,
                    () => settings.PreferencesPage(),
                  ),
                ),
                GoRoute(
                  path: 'swipes',
                  builder: (_, _) => DeferredPage(
                    settings.loadLibrary,
                    () => settings.SwipeSettingsPage(),
                  ),
                ),
                GoRoute(
                  path: 'appearance',
                  builder: (_, _) => DeferredPage(
                    settings.loadLibrary,
                    () => settings.AppearancePage(),
                  ),
                ),
                GoRoute(
                  path: 'sync',
                  builder: (_, _) =>
                      DeferredPage(sync.loadLibrary, () => sync.SyncPage()),
                ),
                GoRoute(
                  path: 'privacy',
                  builder: (_, _) => DeferredPage(
                    settings.loadLibrary,
                    () => settings.PrivacyPage(),
                  ),
                ),
                GoRoute(
                  path: 'about',
                  builder: (_, _) => DeferredPage(
                    settings.loadLibrary,
                    () => settings.AboutPage(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
