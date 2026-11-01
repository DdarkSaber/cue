import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/tokens.dart';
import '../../imports/import_service.dart';
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
  });

  final bool running;
  final int done;
  final int total;

  /// Matched and waiting for the preview's "Import N".
  final StagedImport? staged;
  final String? error;

  bool get idle => !running && staged == null && error == null;
}

class ImportJob extends Notifier<ImportJobState> {
  @override
  ImportJobState build() => const ImportJobState();

  /// Starts matching; a second start while one runs is ignored.
  Future<void> start(
    ParsedImport parsed, {
    Uint8List? rawBytes,
    bool offlineOnly = false,
  }) async {
    if (state.running) return;
    state = ImportJobState(running: true, total: parsed.records.length);
    try {
      final profileId = await ref.read(profileIdProvider.future);
      final staged = await ref
          .read(importServiceProvider)
          .stage(
            profileId,
            parsed,
            rawBytes: rawBytes,
            offlineOnly: offlineOnly,
            onProgress: (done, total) =>
                state = ImportJobState(running: true, done: done, total: total),
          );
      state = ImportJobState(
        staged: staged,
        done: state.total,
        total: state.total,
      );
    } on Object {
      state = const ImportJobState(
        error: 'Matching stopped. Try the import again.',
      );
    }
  }

  /// The preview was imported or cancelled.
  void clear() => state = const ImportJobState();
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
    final text = job.running
        ? 'Matching your import: ${job.done} of ${job.total}'
        : job.staged != null
        ? 'Your import is ready to review'
        : job.error!;
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
