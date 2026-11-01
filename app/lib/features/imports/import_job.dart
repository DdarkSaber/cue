import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/tokens.dart';
import '../../imports/import_service.dart';
import '../../imports/import_draft.dart';
import '../../imports/records.dart';

/// Matching an import against the catalogs can take minutes (AniList allows
/// about 30 lookups a minute). It runs here, outside the import screen, so
/// the person can keep swiping and come back when it is ready.
class ImportJobState {
  const ImportJobState({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.staged,
    this.error,
    this.profileId,
    this.dayFirst = false,
  });

  final bool running;
  final int done;
  final int total;

  /// Matched and waiting for the preview's "Import N".
  final StagedImport? staged;
  final String? error;
  final String? profileId;
  final bool dayFirst;

  bool get idle => !running && staged == null && error == null;
}

class ImportJob extends Notifier<ImportJobState> {
  int _epoch = 0;
  String? _profileId;
  ImportDraft? _draft;
  Future<void> _restored = Future.value();
  Future<void> _writes = Future.value();

  bool _current(int epoch) => ref.mounted && epoch == _epoch;

  /// Disk mutations are ordered, including cancellation and preview edits.
  Future<T> _write<T>(Future<T> Function() action) {
    final result = _writes.then((_) => action());
    // A failed write reaches its caller, but must not poison the next write.
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  ImportJobState build() {
    final profile = ref.watch(profileIdProvider.future);
    final store = ref.watch(importDraftStoreProvider);
    final service = ref.watch(importServiceProvider);
    final epoch = ++_epoch;
    _profileId = null;
    _draft = null;
    ref.onDispose(() => _epoch++);
    _restored = _restore(profile, store, service, epoch);
    return const ImportJobState();
  }

  Uint8List? get rawBytes => _draft?.rawBytes;
  bool get offlineOnly => _draft?.offlineOnly ?? false;

  Future<void> _restore(
    Future<String> profile,
    ImportDraftStore store,
    ImportService service,
    int epoch,
  ) async {
    try {
      final id = await profile;
      if (!_current(epoch)) return;
      _profileId = id;
      final draft = await _write(() => store.load(id));
      if (!_current(epoch)) return;
      _draft = draft;
      if (draft == null) {
        state = ImportJobState(profileId: id);
      } else if (draft.ready) {
        _showReady(draft, id);
      } else {
        unawaited(_run(draft, id, store, service, epoch));
      }
    } on Object catch (error) {
      if (_current(epoch)) {
        _fail(
          'Could not restore your import. Retry or choose the file again.',
          error,
        );
      }
    }
  }

  void _fail(String message, Object error) {
    // Do not log the payload, filenames or catalog query text.
    debugPrint('Import job failed (${error.runtimeType}).');
    state = ImportJobState(
      profileId: _profileId,
      staged: state.staged,
      done: state.done,
      total: state.total,
      dayFirst: state.dayFirst,
      error: message,
    );
  }

  void _showReady(ImportDraft draft, String id) {
    state = ImportJobState(
      profileId: id,
      staged: draft.staged,
      done: draft.matched.length,
      total: draft.parsed.records.length,
      dayFirst: draft.dayFirst,
    );
  }

  /// Starts matching; a second start while one runs is ignored.
  Future<void> start(
    ParsedImport parsed, {
    Uint8List? rawBytes,
    bool offlineOnly = false,
    bool dayFirst = false,
  }) async {
    await _restored;
    if (!ref.mounted) return;
    if (state.running) return;
    final id = _profileId;
    if (id == null) {
      _fail(
        'Could not open this library. Try again.',
        StateError('No profile'),
      );
      return;
    }
    final epoch = ++_epoch;
    final store = ref.read(importDraftStoreProvider);
    final service = ref.read(importServiceProvider);
    state = ImportJobState(
      profileId: id,
      running: true,
      total: parsed.records.length,
    );
    try {
      final draft = await _write(
        () => store.create(
          id,
          parsed,
          rawBytes: rawBytes,
          offlineOnly: offlineOnly,
          dayFirst: dayFirst,
        ),
      );
      if (!_current(epoch)) return;
      _draft = draft;
      await _run(draft, id, store, service, epoch);
    } on Object catch (error) {
      if (_current(epoch)) {
        _fail(
          'Could not save your import. Choose the file again to retry.',
          error,
        );
      }
    }
  }

  Future<void> _run(
    ImportDraft draft,
    String id,
    ImportDraftStore store,
    ImportService service,
    int epoch,
  ) async {
    state = ImportJobState(
      profileId: id,
      running: true,
      done: draft.matched.length,
      total: draft.parsed.records.length,
      dayFirst: draft.dayFirst,
    );
    try {
      final staged = await service.stage(
        id,
        draft.parsed,
        rawBytes: draft.rawBytes,
        offlineOnly: draft.offlineOnly,
        checkpoint: draft.matched,
        onCheckpoint: (matched) async {
          if (!_current(epoch)) throw const _ImportStopped();
          draft.matched = matched;
          await _write(() async {
            if (!_current(epoch)) throw const _ImportStopped();
            await store.save(id, draft);
          });
          if (!_current(epoch)) throw const _ImportStopped();
          state = ImportJobState(
            profileId: id,
            running: true,
            done: matched.length,
            total: draft.parsed.records.length,
            dayFirst: draft.dayFirst,
          );
        },
      );
      if (!_current(epoch)) return;
      draft.existing = staged.existing;
      draft.ready = true;
      await _write(() async {
        if (!_current(epoch)) throw const _ImportStopped();
        await store.save(id, draft);
      });
      if (_current(epoch)) _showReady(draft, id);
    } on _ImportStopped {
      // Disposing or changing profiles leaves the last disk checkpoint intact.
    } on Object catch (error) {
      if (_current(epoch)) {
        _fail('Matching stopped. Your saved import can be retried.', error);
      }
    }
  }

  Future<void> retry() async {
    await _restored;
    if (!ref.mounted || state.running) return;
    final store = ref.read(importDraftStoreProvider);
    final service = ref.read(importServiceProvider);
    final profile = ref.read(profileIdProvider.future);
    _restored = _restore(profile, store, service, ++_epoch);
    await _restored;
  }

  /// Persists ticks without changing the user's preview or committing anything.
  Future<void> savePreview() async {
    final draft = _draft;
    final id = _profileId;
    if (draft == null || id == null || state.running) return;
    final epoch = _epoch;
    final store = ref.read(importDraftStoreProvider);
    try {
      await _write(() async {
        if (!_current(epoch)) throw const _ImportStopped();
        await store.save(id, draft);
      });
      if (_current(epoch)) _showReady(draft, id);
    } on _ImportStopped {
      // The old profile's preview must not overwrite the new profile.
    } on Object catch (error) {
      if (_current(epoch)) {
        _fail('Could not save your preview changes. Try again.', error);
      }
    }
  }

  Future<ImportSummary?> commit(StagedImport staged) async {
    final id = _profileId;
    final epoch = _epoch;
    final service = ref.read(importServiceProvider);
    final library = ref.read(libraryRepositoryProvider);
    try {
      final summary = await _write(() async {
        if (!_current(epoch) ||
            id == null ||
            _draft == null ||
            staged.draftId != _draft!.id) {
          throw StateError('The active import preview changed');
        }
        return service.commit(id, staged);
      });
      await library.recomputeWeights(id!);
      if (_current(epoch)) {
        ref.read(libraryVersionProvider.notifier).bump();
        _draft = null;
        state = ImportJobState(profileId: id);
      }
      return summary;
    } on Object catch (error) {
      if (_current(epoch)) {
        _fail('Could not import your preview. Try again.', error);
      }
      return null;
    }
  }

  /// The preview was imported or cancelled.
  Future<bool> clear() async {
    await _restored;
    if (!ref.mounted) return false;
    final id = _profileId;
    if (id == null) return false;
    final epoch = ++_epoch;
    final store = ref.read(importDraftStoreProvider);
    try {
      await _write(() => store.discard(id));
      if (!_current(epoch)) return false;
      _draft = null;
      state = ImportJobState(profileId: id);
      return true;
    } on Object catch (error) {
      if (_current(epoch)) {
        _fail('Could not cancel your saved import. Try again.', error);
      }
      return false;
    }
  }
}

class _ImportStopped implements Exception {
  const _ImportStopped();
}

final importJobProvider = NotifierProvider<ImportJob, ImportJobState>(
  ImportJob.new,
);

/// A quiet line on the deck while an import is matching or waiting for
/// review. Tapping it opens the import screen where the job is shown.
class ImportJobBanner extends ConsumerWidget {
  const ImportJobBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(importJobProvider);
    if (job.idle) return const SizedBox.shrink();
    final text =
        job.error ??
        (job.running
            ? 'Matching your import: ${job.done} of ${job.total}'
            : 'Your import is ready to review');
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => context.go(CueRoutes.importer),
        style: TextButton.styleFrom(
          minimumSize: const Size(CueSize.minTarget, CueSize.minTarget),
          foregroundColor: CueColors.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Text('$text · Open', style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
