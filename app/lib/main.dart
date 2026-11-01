import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'app/tokens.dart';
import 'data/db/database.dart';

Future<void> main() async {
  // Real paths (/settings) instead of /#/settings, so links and refreshes work.
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) await preloadDeferred();
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  final db = CueDatabase.open();
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const CueApp(),
    ),
  );
}

class CueApp extends StatefulWidget {
  const CueApp({super.key, this.router});

  /// Injected in tests; the app builds its own otherwise.
  final GoRouter? router;

  @override
  State<CueApp> createState() => _CueAppState();
}

class _CueAppState extends State<CueApp> {
  late final GoRouter _router = widget.router ?? buildRouter();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: CueColors.bg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: MaterialApp.router(
        title: 'Cue',
        debugShowCheckedModeBanner: false,
        theme: buildCueTheme(),
        themeMode: ThemeMode.dark,
        routerConfig: _router,
        builder: (context, child) => _AppMotion(child: child!),
      ),
    );
  }
}

/// Applies the in-app "Reduce motion" setting on top of the system one:
/// the system can always ask for less, never for more.
class _AppMotion extends ConsumerWidget {
  const _AppMotion({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduce = ref.watch(
      currentSettingsProvider.select((s) => s.reduceMotion),
    );
    if (!reduce) return child;
    final mq = MediaQuery.of(context);
    return MediaQuery(data: mq.copyWith(disableAnimations: true), child: child);
  }
}
