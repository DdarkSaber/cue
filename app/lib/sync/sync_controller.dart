import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'sync_crypto.dart';
import 'sync_service.dart';

class SyncStatus {
  const SyncStatus({
    this.enabled = false,
    this.busy = false,
    this.lastSynced,
    this.message,
    this.code,
  });

  final bool enabled;
  final bool busy;
  final DateTime? lastSynced;

  /// Plain-language outcome of the last attempt.
  final String? message;

  /// The code in display form, only while enabled.
  final String? code;

  SyncStatus copyWith({
    bool? enabled,
    bool? busy,
    DateTime? lastSynced,
    String? message,
    bool clearMessage = false,
    String? code,
    bool clearCode = false,
  }) => SyncStatus(
    enabled: enabled ?? this.enabled,
    busy: busy ?? this.busy,
    lastSynced: lastSynced ?? this.lastSynced,
    message: clearMessage ? null : (message ?? this.message),
    code: clearCode ? null : (code ?? this.code),
  );
}

String displayCode(String normalized) => [
  for (var i = 0; i < normalized.length; i += 4) normalized.substring(i, i + 4),
].join('-');

String syncMessage(Object e) => switch (e) {
  SyncFailed(code: 'offline') =>
    'Offline. Cue will sync when you are back online.',
  SyncFailed(code: 'bad_code') =>
    'That is not a Cue sync code. Check the 32 characters.',
  SyncFailed(code: 'no_copy') => 'No synced library found for that code.',
  SyncFailed(code: 'quota') =>
    'Sync storage is full right now; your library is safe on this device. '
        'Try again tomorrow.',
  SyncFailed(code: 'http_503') => 'Sync is not set up on this Cue yet.',
  SyncFailed(code: 'http_403') =>
    'That code does not match the synced library.',
  SyncDecryptFailed() => 'The synced copy could not be opened with that code.',
  _ => 'Sync did not finish. Your library on this device is unchanged.',
};

/// Sync state for the active library, with automatic sync shortly after
/// changes and when the app opens.
class SyncController extends AsyncNotifier<SyncStatus> {
  Timer? _debounce;

  static const debounce = Duration(seconds: 20);

  @override
  Future<SyncStatus> build() async {
    // Coming back to the app pulls what other devices changed meanwhile.
    final life = AppLifecycleListener(onResume: schedule);
    ref.onDispose(() {
      _debounce?.cancel();
      life.dispose();
    });
    final profileId = await ref.watch(profileIdProvider.future);
    if (!ref.mounted) return const SyncStatus();
    final service = ref.watch(syncServiceProvider);
    final code = await service.code(profileId);
    if (!ref.mounted) return const SyncStatus();
    final lastSynced = await service.lastSynced(profileId);
    if (!ref.mounted) return const SyncStatus();
    // Library changes from anywhere schedule a quiet sync.
    ref.listen(decisionVersionProvider, (_, _) => schedule());
    ref.listen(libraryVersionProvider, (_, _) => schedule());
    return SyncStatus(
      enabled: code != null,
      code: code == null ? null : displayCode(code),
      lastSynced: lastSynced,
    );
  }

  SyncService get _service => ref.read(syncServiceProvider);
  Future<String> get _profile => ref.read(profileIdProvider.future);

  void schedule() {
    if (state.value?.enabled != true) return;
    _debounce?.cancel();
    _debounce = Timer(debounce, () => syncNow(quiet: true));
  }

  Future<void> _run(Future<void> Function(String profileId) body) async {
    final current = state.value ?? const SyncStatus();
    state = AsyncData(current.copyWith(busy: true, clearMessage: true));
    try {
      await body(await _profile);
    } on Object catch (e) {
      state = AsyncData(
        (state.value ?? current).copyWith(busy: false, message: syncMessage(e)),
      );
      return;
    }
    state = AsyncData((state.value ?? current).copyWith(busy: false));
  }

  Future<void> enable() => _run((id) async {
    final code = await _service.enable(id);
    state = AsyncData(
      SyncStatus(
        enabled: true,
        code: code,
        lastSynced: await _service.lastSynced(id),
        message: 'Sync is on. Enter this code on your other device.',
      ),
    );
  });

  Future<void> join(String code) => _run((id) async {
    final r = await _service.join(id, code);
    final stored = await _service.code(id);
    state = AsyncData(
      SyncStatus(
        enabled: true,
        code: stored == null ? null : displayCode(stored),
        lastSynced: await _service.lastSynced(id),
        message: r.pulled == 0
            ? 'Joined. Both devices now share one library.'
            : 'Joined. ${r.pulled} titles came over from your other device.',
      ),
    );
    ref.read(libraryVersionProvider.notifier).bump();
  });

  Future<void> syncNow({bool quiet = false}) => _run((id) async {
    final r = await _service.syncNow(id);
    if (r.moodChanged) {
      // Drop the old learner without saving, then load the merged one.
      try {
        (await ref.read(moodEngineProvider.future)).forget();
      } on Object {
        // Not loaded yet.
      }
      ref.invalidate(moodEngineProvider);
    }
    if (r.pulled > 0 || r.moodChanged) ref.invalidate(settingsProvider);
    state = AsyncData(
      (state.value ?? const SyncStatus()).copyWith(
        lastSynced: await _service.lastSynced(id),
        message: quiet
            ? null
            : r.pulled == 0
            ? 'Up to date.'
            : '${r.pulled} titles updated from your other devices.',
        clearMessage: quiet,
      ),
    );
    if (r.pulled > 0) ref.read(libraryVersionProvider.notifier).bump();
  });

  Future<void> disable() => _run((id) async {
    await _service.disable(id);
    state = const AsyncData(
      SyncStatus(
        message: 'Sync is off on this device. Your library stays here.',
      ),
    );
  });

  Future<void> deleteRemote() => _run((id) async {
    await _service.deleteRemote(id);
    state = const AsyncData(
      SyncStatus(message: 'The encrypted copy was deleted. Sync is off.'),
    );
  });

  /// Called once when the app opens.
  Future<void> onAppStart() async {
    final s = await future;
    if (s.enabled) await syncNow(quiet: true);
  }
}

final syncControllerProvider =
    AsyncNotifierProvider<SyncController, SyncStatus>(SyncController.new);
