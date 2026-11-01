import 'dart:convert';

import 'package:cue/data/backup_service.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/data/try_now_repository.dart';
import 'package:cue/domain/decisions.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late CueDatabase db;
  late DecisionService decisions;
  late LibraryRepository library;
  late ProfileRepository profiles;
  late String profile;
  late Title title;
  var now = DateTime.utc(2026, 11, 1, 10);

  setUp(() async {
    db = memoryDb();
    profiles = ProfileRepository(db, clock: () => now);
    profile = (await profiles.ensureActive()).id;
    decisions = DecisionService(db, clock: () => now);
    library = LibraryRepository(db, clock: () => now);
    final catalog = CatalogRepository(db, FakeGateway(), clock: () => now);
    await catalog.upsert([CatalogItemDto(item(10))]);
    title = (await catalog.titleById('anilist:10'))!;
  });

  tearDown(() => db.close());

  test(
    'Try now saves an ordinary shortlist intent without invented history',
    () async {
      final result = await decisions.tryNow(profile, title);

      expect(result.tryNow, isTrue);
      expect(result.alreadySaved, isFalse);
      expect(result.decision, Decision.willTry);
      expect((await library.shortlist(profile)).single.id, title.id);
      expect(await library.entry(profile, title.id), isNull);
      final event = await db.select(db.decisionEvents).getSingle();
      expect(event.action, 'try_now');
      expect(event.context, 'tryNow');
      expect((await library.signals(profile)).shortlisted, {title.id});
    },
  );

  test(
    'promotion is idempotent and preserves an existing saved date',
    () async {
      await decisions.decide(profile, title, Decision.willTry);
      final savedBefore = (await db.select(db.shortlist).getSingle()).addedAt;
      final first = await decisions.tryNow(profile, title);
      now = now.add(const Duration(seconds: 5));
      final repeated = await decisions.tryNow(profile, title);

      expect(first.alreadySaved, isTrue);
      expect(first.repeated, isFalse);
      expect(repeated.alreadySaved, isTrue);
      expect(repeated.repeated, isTrue);
      expect(repeated.eventId, first.eventId);
      expect((await db.select(db.shortlist).getSingle()).addedAt, savedBefore);
      expect(
        (await db.select(db.decisionEvents).get())
            .where((event) => event.action == 'try_now')
            .length,
        1,
      );
      expect(await TryNowRepository(db).isActive(profile, title.id), isTrue);
    },
  );

  test('ordinary Will try clears a stale stronger-interest marker', () async {
    await decisions.tryNow(profile, title);
    now = now.add(const Duration(seconds: 1));
    await decisions.decide(profile, title, Decision.willTry);

    expect(await TryNowRepository(db).isActive(profile, title.id), isFalse);
    expect((await library.signals(profile)).shortlisted, {title.id});
  });

  test(
    'saved priority metadata never increases permanent taste evidence',
    () async {
      await decisions.decide(profile, title, Decision.willTry);
      await library.recomputeWeights(profile);
      final ordinary = await library.signals(profile);
      await decisions.tryNow(profile, title);
      await library.recomputeWeights(profile);
      final priority = await library.signals(profile);
      expect(priority.weights, ordinary.weights);
      expect(priority.evidenceTitles, ordinary.evidenceTitles);
      expect(priority.evidenceStrength, ordinary.evidenceStrength);
      expect(priority.kindRatings, ordinary.kindRatings);
      expect(await library.entry(profile, title.id), isNull);
    },
  );

  test(
    'Undo after service restart restores prior shortlist date and marker',
    () async {
      await decisions.decide(profile, title, Decision.willTry);
      final savedBefore = (await db.select(db.shortlist).getSingle()).addedAt;
      final promoted = await decisions.tryNow(profile, title);
      final restarted = DecisionService(db, clock: () => now);

      final undo = await restarted.undoLast(profile);

      expect(undo, isNotNull);
      expect(undo!.tryNow, isTrue);
      expect(undo.eventId, promoted.eventId);
      expect((await db.select(db.shortlist).getSingle()).addedAt, savedBefore);
      expect(await TryNowRepository(db).isActive(profile, title.id), isFalse);
    },
  );

  test(
    'Undo of a newly saved title removes only its shortlist marker',
    () async {
      final promoted = await decisions.tryNow(profile, title);
      now = now.add(const Duration(seconds: 1));

      final undo = await decisions.undoLast(profile);

      expect(undo!.tryNow, isTrue);
      expect(undo.eventId, promoted.eventId);
      expect(await db.select(db.shortlist).get(), isEmpty);
      expect(await library.entry(profile, title.id), isNull);
      expect(await TryNowRepository(db).isActive(profile, title.id), isFalse);
    },
  );

  test(
    'Undo works with a fractional clock and persisted shortlist precision',
    () async {
      final preciseClock = DateTime.utc(2026, 11, 1, 10, 0, 0, 686, 513);
      final preciseService = DecisionService(db, clock: () => preciseClock);
      final promoted = await preciseService.tryNow(profile, title);

      final undo = await preciseService.undoTryNow(profile, promoted.eventId);

      expect(undo, isNotNull);
      expect(undo!.tryNow, isTrue);
      expect(await db.select(db.shortlist).get(), isEmpty);
    },
  );

  test('a stale Undo will not overwrite a newer clear', () async {
    await decisions.tryNow(profile, title);
    now = now.add(const Duration(milliseconds: 1));
    await TryNowRepository(db, clock: () => now).clear(profile, title.id);

    expect(await decisions.undoLast(profile), isNull);
    expect(await TryNowRepository(db).isActive(profile, title.id), isFalse);
    expect(await db.select(db.shortlist).get(), hasLength(1));
  });

  test('Try now Undo refuses to overwrite a later library edit', () async {
    final promoted = await decisions.tryNow(profile, title);
    now = now.add(const Duration(seconds: 1));
    await library.saveEntry(
      profile,
      title.id,
      state: LibraryState.seen,
      rating: Rating.enjoyed,
    );

    expect(await decisions.undoTryNow(profile, promoted.eventId), isNull);
    final entry = await library.entry(profile, title.id);
    expect(entry?.state, LibraryState.seen);
    expect(entry?.rating, Rating.enjoyed);
    expect(await TryNowRepository(db).isActive(profile, title.id), isTrue);
  });

  test(
    'promotion requires an existing profile inside its transaction',
    () async {
      await expectLater(
        decisions.tryNow('deleted-profile', title),
        throwsA(isA<DecisionFailed>()),
      );
      expect(await db.select(db.shortlist).get(), isEmpty);
      expect(await db.select(db.decisionEvents).get(), isEmpty);
    },
  );

  test('metadata is profile-isolated', () async {
    final other = (await profiles.create()).id;
    await decisions.tryNow(profile, title);

    expect(await TryNowRepository(db).isActive(profile, title.id), isTrue);
    expect(await TryNowRepository(db).isActive(other, title.id), isFalse);
  });

  test(
    'removing a saved title tombstones priority for only its profile',
    () async {
      final other = (await profiles.create()).id;
      await decisions.tryNow(profile, title);
      await decisions.tryNow(other, title);

      await library.removeFromShortlist(profile, title.id);

      final records = await TryNowRepository(db).all(profile);
      expect(records[title.id]?.active, isFalse);
      expect(await TryNowRepository(db).isActive(other, title.id), isTrue);
    },
  );

  test(
    'reset swipes tombstones active intent and preserves other profiles',
    () async {
      final other = (await profiles.create()).id;
      await decisions.tryNow(profile, title);
      await decisions.tryNow(other, title);

      await library.resetSwipes(profile);

      expect(await TryNowRepository(db).isActive(profile, title.id), isFalse);
      expect(await TryNowRepository(db).isActive(other, title.id), isTrue);
    },
  );

  test('ordinary resave after removal is not a Tonight pick', () async {
    await decisions.tryNow(profile, title);
    await library.removeFromShortlist(profile, title.id);
    await decisions.decide(profile, title, Decision.willTry);

    expect(await TryNowRepository(db).isActive(profile, title.id), isFalse);
    expect((await library.shortlist(profile)).single.id, title.id);
  });

  test('an older remote active marker cannot beat a clear tombstone', () async {
    await decisions.tryNow(profile, title);
    await TryNowRepository(db, clock: () => now).clearTitle(profile, title.id);
    final older = TryNowIntent(
      titleId: title.id,
      active: true,
      updatedAt: now.subtract(const Duration(seconds: 1)),
    );
    await db.transaction(
      () => TryNowRepository(db).mergeInTransaction(profile, {title.id: older}),
    );

    expect(await TryNowRepository(db).isActive(profile, title.id), isFalse);
  });

  for (final operation in ['entry', 'shortlist', 'reset']) {
    test(
      '$operation cleanup survives stale merge and ordinary re-add',
      () async {
        final other = (await profiles.create()).id;
        await library.saveEntry(profile, title.id, state: LibraryState.planned);
        await decisions.tryNow(profile, title);
        await decisions.tryNow(other, title);
        final original = (await TryNowRepository(db).all(profile))[title.id]!;
        now = now.add(const Duration(seconds: 2));
        switch (operation) {
          case 'entry':
            await library.removeEntry(profile, title.id);
          case 'shortlist':
            await library.removeFromShortlist(profile, title.id);
          case 'reset':
            await library.resetSwipes(profile);
        }
        await db.transaction(
          () =>
              TryNowRepository(db)
                  .mergeInTransaction(profile, {title.id: original}),
        );
        expect(await TryNowRepository(db).isActive(profile, title.id), isFalse);
        expect(await TryNowRepository(db).isActive(other, title.id), isTrue);
        await decisions.decide(profile, title, Decision.willTry);
        expect(await TryNowRepository(db).isActive(profile, title.id), isFalse);
        expect((await library.shortlist(profile)).single.id, title.id);
      },
    );
  }

  test(
    'corrupt priority metadata reports failure without deleting saved data',
    () async {
      await decisions.tryNow(profile, title);
      await profiles.setRawSetting(
        profile,
        TryNowRepository.metadataKey,
        '{"invalid":{}}',
      );
      await expectLater(
        library.removeFromShortlist(profile, title.id),
        throwsFormatException,
      );
      expect((await library.shortlist(profile)).single.id, title.id);
      expect(
        await profiles.rawSetting(profile, TryNowRepository.metadataKey),
        '{"invalid":{}}',
      );
    },
  );

  test(
    'ordinary backup includes the durable per-profile intent metadata',
    () async {
      await decisions.tryNow(profile, title);

      final backup = jsonDecode(
        await BackupService(db).export(profile),
      ) as Map<String, dynamic>;
      final settings = backup['settings'] as Map<String, dynamic>;
      expect(settings[TryNowRepository.metadataKey], contains(title.id));
    },
  );
}
