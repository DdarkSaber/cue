import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/anilist_client.dart';
import '../data/backup_service.dart';
import '../data/catalog_gateway.dart';
import '../data/catalog_repository.dart';
import '../data/db/database.dart';
import '../data/library_repository.dart';
import '../data/profile_repository.dart';
import '../domain/decisions.dart';
import '../domain/models/settings.dart';
import '../domain/ranker.dart';
import '../imports/import_service.dart';
import '../imports/token_store.dart';
import '../data/mood_repository.dart';
import '../domain/mood/mood_engine.dart';
import '../sync/sync_service.dart';
import 'config.dart';

/// Overridden in main() with the opened database, and in tests with an
/// in-memory one.
final databaseProvider = Provider<CueDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final catalogGatewayProvider = Provider<CatalogGateway>(
  (ref) => HybridCatalogGateway(
    HttpCatalogGateway(cueApiBase, proxyImages: kIsWeb),
    AniListClient(),
    web: kIsWeb,
  ),
);

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(
    ref.watch(databaseProvider),
    ref.watch(catalogGatewayProvider),
    clock: ref.watch(clockProvider),
  ),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final decisionServiceProvider = Provider<DecisionService>(
  (ref) => DecisionService(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final rankerProvider = Provider<Ranker>(
  (ref) => Ranker(clock: ref.watch(clockProvider)),
);

/// The active local profile id, created silently on first open.
final profileIdProvider = FutureProvider<String>((ref) async {
  final p = await ref.watch(profileRepositoryProvider).ensureActive();
  return p.id;
});

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final id = await ref.watch(profileIdProvider.future);
    return ref.watch(profileRepositoryProvider).loadSettings(id);
  }

  Future<void> change(AppSettings Function(AppSettings) edit) async {
    final current = state.value ?? await future;
    final next = edit(current);
    state = AsyncData(next);
    final id = await ref.read(profileIdProvider.future);
    await ref.read(profileRepositoryProvider).saveSettings(id, next);
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// Settings with defaults while loading, for widgets that only read them.
final currentSettingsProvider = Provider<AppSettings>(
  (ref) => ref.watch(settingsProvider).value ?? const AppSettings(),
);

/// Bumped whenever library data changes outside the deck (imports, edits,
/// restores), so screens reload.
class LibraryVersion extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final libraryVersionProvider = NotifierProvider<LibraryVersion, int>(
  LibraryVersion.new,
);

/// Bumped after every deck decision or undo. Library and Will try watch it;
/// the deck does not (it already knows).
final decisionVersionProvider = NotifierProvider<LibraryVersion, int>(
  LibraryVersion.new,
);

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(
    ref.watch(databaseProvider),
    ref.watch(catalogRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final codeStoreProvider = Provider<CodeStore>((ref) => const SecureCodeStore());

final moodRepositoryProvider = Provider<MoodRepository>(
  (ref) => MoodRepository(ref.watch(databaseProvider)),
);

/// The live mood learner for the active profile. Learns from past sessions
/// on first use (or from liked library titles), and closes the session when
/// the app is hidden.
final moodEngineProvider = FutureProvider<MoodEngine>((ref) async {
  final profileId = await ref.watch(profileIdProvider.future);
  final catalog = ref.read(catalogRepositoryProvider);
  final engine = MoodEngine(
    ref.read(moodRepositoryProvider),
    profileId,
    catalog.titlesByIds,
  );
  await engine.load();
  if (engine.modes.isEmpty) {
    final signals = await ref
        .read(libraryRepositoryProvider)
        .signals(profileId);
    final liked = [
      for (final e in signals.library.entries)
        if ((e.value.rating?.weight ?? 0) >= 2) e.key,
    ];
    await engine.seedFrom(await catalog.titlesByIds(liked));
  }
  final life = AppLifecycleListener(
    onHide: () => unawaited(engine.endSession()),
  );
  ref.onDispose(() {
    life.dispose();
    unawaited(engine.endSession());
  });
  return engine;
});

/// What Cue currently reads the mood as, for the "Cue read" chip.
class MoodReadController extends Notifier<MoodTarget> {
  @override
  MoodTarget build() => MoodTarget.none;
  void set(MoodTarget t) => state = t;
}

final moodReadProvider = NotifierProvider<MoodReadController, MoodTarget>(
  MoodReadController.new,
);

/// Read-only MAL sign-in token, on this device only.
final tokenStoreProvider = Provider<TokenStore>(
  (ref) => const SecureTokenStore(),
);

final syncRemoteProvider = Provider<SyncRemote>(
  (ref) => HttpSyncRemote(cueApiBase),
);

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    remote: ref.watch(syncRemoteProvider),
    codes: ref.watch(codeStoreProvider),
    backup: ref.watch(backupServiceProvider),
    imports: ref.watch(importServiceProvider),
    profiles: ref.watch(profileRepositoryProvider),
    library: ref.watch(libraryRepositoryProvider),
  ),
);
