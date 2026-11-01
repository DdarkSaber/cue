import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cue/app/providers.dart';
import 'package:cue/data/backup_service.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/features/imports/import_job.dart';
import 'package:cue/imports/import_draft.dart';
import 'package:cue/imports/import_service.dart';
import 'package:cue/imports/matcher.dart';
import 'package:cue/imports/records.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

class _SlowGateway extends FakeGateway {
  _SlowGateway({this.blockCall = 2});
  final int blockCall;
  final entered = Completer<void>();
  final release = Completer<void>();
  final queries = <String>[];
  bool disconnect = false;

  @override
  Future<MatchResponse> match(
    List<MatchQuery> items, {
    List<int> malAnime = const [],
    List<int> malManga = const [],
  }) async {
    queries.addAll(items.map((q) => q.q));
    if (matchCalls + 1 == blockCall) {
      entered.complete();
      await release.future;
      if (disconnect) throw StateError('Synthetic request interrupted by exit');
    }
    return super.match(items, malAnime: malAnime, malManga: malManga);
  }
}

class _FailingGateway extends FakeGateway {
  bool fail = true;
  @override
  Future<MatchResponse> match(
    List<MatchQuery> items, {
    List<int> malAnime = const [],
    List<int> malManga = const [],
  }) {
    if (fail) throw StateError('Synthetic matching failure');
    return super.match(items, malAnime: malAnime, malManga: malManga);
  }
}

class _FailingStore extends ImportDraftStore {
  _FailingStore(super.db);
  bool failSave = true;
  bool failDiscard = false;

  @override
  Future<void> save(String profileId, ImportDraft draft) async {
    if (failSave) throw StateError('Synthetic disk write failure');
    await super.save(profileId, draft);
  }

  @override
  Future<void> discard(String profileId) async {
    if (failDiscard) throw StateError('Synthetic disk deletion failure');
    await super.discard(profileId);
  }
}

class _FailingCommit extends ImportService {
  _FailingCommit(super.db, super.catalog);
  bool fail = true;

  @override
  Future<ImportSummary> commit(String profileId, StagedImport staged) {
    if (fail) throw StateError('Synthetic commit failure');
    return super.commit(profileId, staged);
  }
}

void _seed(FakeGateway gateway) {
  for (var i = 1; i <= 13; i++) {
    gateway.matchCatalog['synthetic $i'] = [item(i)];
  }
}

ParsedImport _parsed([int count = 13]) => ParsedImport(
  sourceType: 'mal',
  adapterVersion: 'synthetic-v1',
  records: [
    for (var i = 1; i <= count; i++)
      NormalizedRecord(
        sourceEntryKey: 'row:$i',
        title: 'Synthetic $i',
        kind: MediaKind.anime,
        state: LibraryState.completed,
      ),
  ],
);

Future<ImportJobState> _wait(
  ProviderContainer container,
  bool Function(ImportJobState) predicate,
) async {
  final completer = Completer<ImportJobState>();
  final subscription = container.listen(importJobProvider, (_, state) {
    if (predicate(state) && !completer.isCompleted) completer.complete(state);
  }, fireImmediately: true);
  try {
    return await completer.future.timeout(const Duration(seconds: 10));
  } finally {
    subscription.close();
  }
}

void main() {
  late Directory temp;
  late File file;
  late CueDatabase db;
  late ProviderContainer container;
  late String profile;

  ProviderContainer openContainer(
    FakeGateway gateway, {
    ImportDraftStore? store,
  }) => ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      catalogGatewayProvider.overrideWithValue(gateway),
      if (store != null) importDraftStoreProvider.overrideWithValue(store),
    ],
  );

  Future<void> restart(FakeGateway gateway) async {
    container.dispose();
    await db.close();
    db = CueDatabase(NativeDatabase(file));
    container = openContainer(gateway);
    container.read(importJobProvider);
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cue-import-restart-');
    file = File('${temp.path}${Platform.pathSeparator}cue.sqlite');
    db = CueDatabase(NativeDatabase(file));
    profile = (await ProfileRepository(db).ensureActive()).id;
    final gateway = FakeGateway();
    _seed(gateway);
    container = openContainer(gateway);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await temp.delete(recursive: true);
  });

  test(
    'restart resumes completed chunks without committing the preview',
    () async {
      container.dispose();
      final slow = _SlowGateway();
      _seed(slow);
      container = openContainer(slow);
      final bytes = Uint8List.fromList(utf8.encode('synthetic-file'));
      final running = container
          .read(importJobProvider.notifier)
          .start(_parsed(), rawBytes: bytes);
      await slow.entered.future;
      expect(container.read(importJobProvider).done, 12);
      final checkpoint = await ImportDraftStore(db).load(profile);
      expect(checkpoint!.matched.length, 12);
      expect(checkpoint.ready, isFalse);
      expect(await db.select(db.userTitles).get(), isEmpty);

      // Kill the provider while a real catalog request is pending, then close
      // and reopen the SQLite file. An in-flight result must not change disk.
      container.dispose();
      slow.disconnect = true;
      slow.release.complete();
      await running;
      final afterDispose = await ImportDraftStore(db).load(profile);
      expect(afterDispose!.matched.length, 12);
      await db.close();
      db = CueDatabase(NativeDatabase(file));
      final resumed = _SlowGateway(blockCall: 99);
      _seed(resumed);
      container = openContainer(resumed);
      final ready = await _wait(container, (s) => s.staged != null);
      expect(ready.done, 13);
      expect(resumed.queries, ['Synthetic 13']);
      expect(ready.staged!.matched.first.matchClass, MatchClass.suggested);
      expect(ready.staged!.draftId, checkpoint.id);
      expect(ready.staged!.fingerprint, checkpoint.staged.fingerprint);
      expect(await db.select(db.userTitles).get(), isEmpty);
      expect(await db.select(db.sourceObservations).get(), isEmpty);
      final exported =
          jsonDecode(await BackupService(db).export(profile)) as Map;
      expect(exported['items'], isEmpty);
      expect(jsonEncode(exported), isNot(contains('synthetic-file')));

      // Restart once more with a ready preview: no network, no auto-commit.
      await restart(FakeGateway(offline: true));
      final restored = await _wait(container, (s) => s.staged != null);
      expect(restored.staged!.matched.length, 13);
      expect(await db.select(db.userTitles).get(), isEmpty);
      final summary = await container
          .read(importJobProvider.notifier)
          .commit(restored.staged!);
      expect(summary!.added, 13);
      expect(await ImportDraftStore(db).load(profile), isNull);
      expect((await db.select(db.userTitles).get()).length, 13);
      final completed = await db.select(db.importBatches).getSingle();
      expect(completed.countsJson, isNot(contains('rawBytes')));
      await restart(FakeGateway(offline: true));
      final idle = await _wait(container, (s) => s.profileId == profile);
      expect(idle.idle, isTrue);
    },
  );

  test('ready preview inclusion choices survive restart', () async {
    await container.read(importJobProvider.notifier).start(_parsed(2));
    final staged = container.read(importJobProvider).staged!;
    staged.matched.first.included = false;
    await container.read(importJobProvider.notifier).savePreview();
    await restart(FakeGateway(offline: true));
    final ready = await _wait(container, (s) => s.staged != null);
    expect(ready.staged!.matched.first.included, isFalse);
    expect(ready.staged!.matched.last.included, isTrue);
    final summary = await container
        .read(importJobProvider.notifier)
        .commit(ready.staged!);
    expect(summary!.added, 1);
    expect((await db.select(db.userTitles).get()).single.titleId, 'anilist:2');
  });

  test(
    'stable draft id makes fileless concurrent commits idempotent',
    () async {
      await container.read(importJobProvider.notifier).start(_parsed(2));
      final staged = container.read(importJobProvider).staged!;
      final imports = container.read(importServiceProvider);
      final summaries = await Future.wait([
        imports.commit(profile, staged),
        imports.commit(profile, staged),
      ]);
      expect(summaries.where((s) => s.alreadyImported).length, 1);
      expect((await db.select(db.importBatches).get()).length, 1);
      expect((await db.select(db.userTitles).get()).length, 2);
      await restart(FakeGateway(offline: true));
      expect(
        (await _wait(container, (s) => s.profileId == profile)).idle,
        isTrue,
      );
    },
  );

  test(
    'reimporting the same file consumes its draft without duplicating',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final job = container.read(importJobProvider.notifier);
      await job.start(_parsed(1), rawBytes: bytes);
      expect(
        (await job.commit(container.read(importJobProvider).staged!))!.added,
        1,
      );
      await job.start(_parsed(1), rawBytes: bytes);
      final summary = await job.commit(
        container.read(importJobProvider).staged!,
      );
      expect(summary!.alreadyImported, isTrue);
      expect(await ImportDraftStore(db).load(profile), isNull);
      expect((await db.select(db.importBatches).get()).length, 1);
      expect((await db.select(db.userTitles).get()).length, 1);
    },
  );

  test(
    'switching profiles stops old matching and isolates each preview',
    () async {
      container.dispose();
      final slow = _SlowGateway();
      _seed(slow);
      container = openContainer(slow);
      final oldJob = container.read(importJobProvider.notifier);
      final running = oldJob.start(_parsed());
      await slow.entered.future;
      final second = (await ProfileRepository(db).create()).id;
      container.invalidate(profileIdProvider);
      final idle = await _wait(container, (s) => s.profileId == second);
      expect(idle.idle, isTrue);
      slow.release.complete();
      await running;
      expect((await ImportDraftStore(db).load(profile))!.matched.length, 12);
      expect(await ImportDraftStore(db).load(second), isNull);
      await container.read(importJobProvider.notifier).start(_parsed(1));
      final secondPreview = container.read(importJobProvider).staged!;
      await expectLater(
        container.read(importServiceProvider).commit(profile, secondPreview),
        throwsStateError,
      );
      await container.read(importJobProvider.notifier).savePreview();
      await ProfileRepository(db).activate(profile);
      container.invalidate(profileIdProvider);
      final firstReady = await _wait(
        container,
        (s) => s.profileId == profile && s.staged != null,
      );
      expect(firstReady.staged!.matched.length, 13);
      expect(firstReady.staged!.draftId, isNot(secondPreview.draftId));
      expect((await ImportDraftStore(db).load(second))!.ready, isTrue);
      expect(await db.select(db.userTitles).get(), isEmpty);
    },
  );

  test('cancelling a pending request cannot resurrect a draft', () async {
    container.dispose();
    final slow = _SlowGateway();
    _seed(slow);
    container = openContainer(slow);
    final job = container.read(importJobProvider.notifier);
    final running = job.start(_parsed());
    await slow.entered.future;
    expect(await job.clear(), isTrue);
    slow.release.complete();
    await running;
    expect(await ImportDraftStore(db).load(profile), isNull);
    expect(await db.select(db.userTitles).get(), isEmpty);
    await restart(FakeGateway());
    expect(
      (await _wait(container, (s) => s.profileId == profile)).idle,
      isTrue,
    );
  });

  test('matching errors retain input and can be retried', () async {
    container.dispose();
    final gateway = _FailingGateway();
    _seed(gateway);
    container = openContainer(gateway);
    await container.read(importJobProvider.notifier).start(_parsed(1));
    expect(container.read(importJobProvider).error, contains('saved import'));
    expect(await ImportDraftStore(db).load(profile), isNotNull);
    gateway.fail = false;
    await container.read(importJobProvider.notifier).retry();
    final ready = await _wait(container, (s) => s.staged != null);
    expect(ready.staged!.readyNew, 1);
    expect(await db.select(db.userTitles).get(), isEmpty);
  });

  test(
    'failed checkpoint writes and failed cancellation are explicit',
    () async {
      container.dispose();
      final gateway = FakeGateway();
      _seed(gateway);
      final store = _FailingStore(db);
      container = openContainer(gateway, store: store);
      final job = container.read(importJobProvider.notifier);
      await job.start(_parsed(1));
      expect(
        container.read(importJobProvider).error,
        contains('Matching stopped'),
      );
      expect(container.read(importJobProvider).staged, isNull);
      expect((await ImportDraftStore(db).load(profile))!.matched, isEmpty);
      store.failSave = false;
      await job.retry();
      await _wait(container, (s) => s.staged != null);
      store.failDiscard = true;
      expect(await job.clear(), isFalse);
      expect(
        container.read(importJobProvider).error,
        contains('Could not cancel'),
      );
      expect(await ImportDraftStore(db).load(profile), isNotNull);
      store.failDiscard = false;
      expect(await job.clear(), isTrue);
    },
  );

  test(
    'corrupt checkpoint is reported rather than silently discarded',
    () async {
      await container.read(importJobProvider.notifier).start(_parsed(1));
      await db
          .update(db.importBatches)
          .write(
            const ImportBatchesCompanion(countsJson: Value('{"version":999}')),
          );
      await restart(FakeGateway());
      final failed = await _wait(container, (s) => s.error != null);
      expect(failed.error, contains('Could not restore'));
      expect(await db.select(db.userTitles).get(), isEmpty);
      expect((await db.select(db.importBatches).get()).length, 1);
      expect(await container.read(importJobProvider.notifier).clear(), isTrue);
      expect(await db.select(db.importBatches).get(), isEmpty);
    },
  );

  test(
    'failed commit keeps the durable preview for an explicit retry',
    () async {
      container.dispose();
      final gateway = FakeGateway();
      _seed(gateway);
      final imports = _FailingCommit(db, CatalogRepository(db, gateway));
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          catalogGatewayProvider.overrideWithValue(gateway),
          importServiceProvider.overrideWithValue(imports),
        ],
      );
      final job = container.read(importJobProvider.notifier);
      await job.start(_parsed(1));
      final staged = container.read(importJobProvider).staged!;
      expect(await job.commit(staged), isNull);
      expect(
        container.read(importJobProvider).error,
        contains('Could not import'),
      );
      expect(container.read(importJobProvider).staged, same(staged));
      expect((await ImportDraftStore(db).load(profile))!.ready, isTrue);
      expect(await db.select(db.userTitles).get(), isEmpty);
      imports.fail = false;
      expect((await job.commit(staged))!.added, 1);
      expect(container.read(importJobProvider).idle, isTrue);
      expect(await ImportDraftStore(db).load(profile), isNull);
    },
  );

  test(
    'failed preview save is visible and does not claim durable changes',
    () async {
      container.dispose();
      final gateway = FakeGateway();
      _seed(gateway);
      final store = _FailingStore(db)..failSave = false;
      container = openContainer(gateway, store: store);
      final job = container.read(importJobProvider.notifier);
      await job.start(_parsed(1));
      container.read(importJobProvider).staged!.matched.first.included = false;
      store.failSave = true;
      await job.savePreview();
      expect(
        container.read(importJobProvider).error,
        contains('Could not save'),
      );
      expect(
        (await ImportDraftStore(db).load(profile))!.matched.first.included,
        isTrue,
      );
      store.failSave = false;
      await job.savePreview();
      await restart(FakeGateway(offline: true));
      final ready = await _wait(container, (s) => s.staged != null);
      expect(ready.staged!.matched.first.included, isFalse);
    },
  );

  test('checkpoint round trips all input and match metadata', () async {
    final date = DateTime.utc(2026, 4, 5, 6, 7);
    final record = NormalizedRecord(
      sourceEntryKey: 'all-fields',
      title: 'Synthetic 1',
      altTitles: const ['Synthetic alternate'],
      cueId: 'anilist:1',
      kind: MediaKind.anime,
      malId: 2,
      anilistId: 1,
      year: 2024,
      state: LibraryState.partial,
      statusOriginal: 'synthetic status',
      rating: Rating.wouldRewatch,
      ratingOriginal: '9',
      ratingScale: '10',
      rewatchMood: RewatchMood.comfort,
      progressUnit: 'episodes',
      progressValue: 2.5,
      latestKnown: 12,
      activityDate: date,
      actualWatchedAt: date,
      plays: 3,
      note: 'Synthetic note',
      confirmed: false,
      screenOnly: true,
    );
    final parsed = ParsedImport(
      sourceType: 'cue',
      adapterVersion: 'synthetic-v1',
      records: [record],
      warnings: const ['Synthetic warning'],
      skipped: 2,
      dateRange: (date, date),
      needsDateOrder: true,
      extras: BackupExtras(
        shortlist: const ['anilist:1'],
        notInterested: const ['anilist:2'],
        notNow: {'anilist:3': date},
        catalog: [item(1)],
        settings: const {'reduce_motion': 'true'},
        showAdult: false,
        region: 'IN',
        displayName: 'Synthetic library',
      ),
    );
    final store = ImportDraftStore(db);
    final draft = await store.create(
      profile,
      parsed,
      rawBytes: Uint8List.fromList([1, 2]),
      offlineOnly: true,
      dayFirst: true,
    );
    draft.matched = [
      MatchedRecord(
        record,
        'anilist:1',
        MatchClass.similar,
        included: false,
        candidate: CatalogItemDto(item(1)),
        unchecked: true,
      ),
    ];
    draft.existing = {'anilist:1'};
    draft.ready = true;
    await store.save(profile, draft);
    final encoded = draft.encode();
    await restart(FakeGateway(offline: true));
    final restored = await ImportDraftStore(db).load(profile);
    expect(restored!.encode(), encoded);
    expect(restored.ready, isTrue);
    expect((await _wait(container, (s) => s.staged != null)).dayFirst, isTrue);
    expect(await db.select(db.userTitles).get(), isEmpty);
  });
}
