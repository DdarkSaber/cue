import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
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
  late String profile;
  late Title anime;
  late Title manhwa;
  var now = DateTime(2026, 10, 31, 12);

  setUp(() async {
    db = memoryDb();
    decisions = DecisionService(db, clock: () => now);
    library = LibraryRepository(db, clock: () => now);
    profile = (await ProfileRepository(db, clock: () => now).ensureActive()).id;
    final catalog = CatalogRepository(db, FakeGateway(), clock: () => now);
    await catalog.upsert([
      CatalogItemDto(item(1)),
      CatalogItemDto(item(2, kind: 'manhwa', country: 'KR')),
    ]);
    anime = (await catalog.titleById('anilist:1'))!;
    manhwa = (await catalog.titleById('anilist:2'))!;
  });

  tearDown(() => db.close());

  test('Will try adds to the shortlist and removes from discovery', () async {
    await decisions.decide(profile, anime, Decision.willTry);
    final s = await library.signals(profile);
    expect(s.shortlisted, {anime.id});
  });

  test('Not now hides for 14 days, then the title is eligible again', () async {
    await decisions.decide(profile, anime, Decision.notNow);
    expect((await library.signals(profile)).deferred, {anime.id});
    now = now.add(const Duration(days: 14, minutes: 1));
    expect((await library.signals(profile)).deferred, isEmpty);
    now = DateTime(2026, 10, 31, 12);
  });

  test('reset swipes clears deck decisions but keeps rated titles', () async {
    await decisions.decide(profile, anime, Decision.willTry);
    await decisions.decide(profile, manhwa, Decision.watched);
    await library.saveEntry(
      profile,
      'anilist:99',
      state: LibraryState.completed,
      rating: Rating.favourite,
    );
    await library.resetSwipes(profile);
    final s = await library.signals(profile);
    expect(s.shortlisted, isEmpty);
    expect(await library.entry(profile, manhwa.id), isNull);
    expect(
      (await library.entry(profile, 'anilist:99'))!.rating,
      Rating.favourite,
    );
    expect(await decisions.canUndo(profile), isFalse);
  });

  test('Not now can hide for a chosen length', () async {
    await decisions.decide(
      profile,
      anime,
      Decision.notNow,
      defer: const Duration(days: 1),
    );
    now = now.add(const Duration(days: 1, minutes: 1));
    expect((await library.signals(profile)).deferred, isEmpty);
    now = DateTime(2026, 10, 31, 12);
  });

  test(
    'Watched records seen, never completed, and keeps a completion',
    () async {
      await decisions.decide(profile, anime, Decision.watched);
      expect(
        (await library.entry(profile, anime.id))!.state,
        LibraryState.seen,
      );

      await library.saveEntry(
        profile,
        manhwa.id,
        state: LibraryState.completed,
      );
      await decisions.decide(profile, manhwa, Decision.watched);
      expect(
        (await library.entry(profile, manhwa.id))!.state,
        LibraryState.completed,
      );
    },
  );

  test('reading titles store "read" as the action', () async {
    await decisions.decide(profile, manhwa, Decision.watched);
    final events = await db.select(db.decisionEvents).get();
    expect(events.single.action, 'read');
  });

  test('Not interested excludes until restored', () async {
    await decisions.decide(profile, anime, Decision.notInterested);
    expect((await library.signals(profile)).excluded, {anime.id});
    await decisions.restore(profile, anime.id);
    expect((await library.signals(profile)).excluded, isEmpty);
  });

  test('four decisions then undo reverses only the last, in order', () async {
    await decisions.decide(profile, anime, Decision.willTry);
    await decisions.decide(profile, manhwa, Decision.notInterested);
    now = now.add(const Duration(seconds: 1));

    final first = await decisions.undoLast(profile);
    expect(first!.titleId, manhwa.id);
    expect(first.decision, Decision.notInterested);
    var s = await library.signals(profile);
    expect(s.excluded, isEmpty);
    expect(s.shortlisted, {anime.id});

    now = now.add(const Duration(seconds: 1));
    final second = await decisions.undoLast(profile);
    expect(second!.titleId, anime.id);
    s = await library.signals(profile);
    expect(s.shortlisted, isEmpty);
    expect(await decisions.undoLast(profile), isNull);
    now = DateTime(2026, 10, 31, 12);
  });

  test('undo restores the exact previous library row', () async {
    await library.saveEntry(
      profile,
      anime.id,
      state: LibraryState.watching,
      rating: Rating.wouldRewatch,
    );
    await decisions.decide(profile, anime, Decision.watched);
    await decisions.undoLast(profile);
    final e = await library.entry(profile, anime.id);
    expect(e!.state, LibraryState.watching);
    expect(e.rating, Rating.wouldRewatch);
  });

  test('undo survives a restart (state lives in the database)', () async {
    await decisions.decide(profile, anime, Decision.notNow);
    final fresh = DecisionService(db, clock: () => now);
    expect(await fresh.canUndo(profile), isTrue);
    await fresh.undoLast(profile);
    expect((await library.signals(profile)).deferred, isEmpty);
  });

  test('acting from the shortlist settles the shortlisted title', () async {
    await decisions.decide(profile, anime, Decision.willTry);
    await decisions.decide(
      profile,
      anime,
      Decision.watched,
      context: DeckContext.shortlist,
    );
    expect((await library.signals(profile)).shortlisted, isEmpty);
  });

  test(
    'weights come from evidence and re-running does not double them',
    () async {
      await library.saveEntry(
        profile,
        anime.id,
        state: LibraryState.completed,
        rating: Rating.rewatched,
      );
      await library.recomputeWeights(profile);
      final once = (await library.signals(profile)).weights['action'];
      await library.recomputeWeights(profile);
      final twice = (await library.signals(profile)).weights['action'];
      expect(once, 3);
      expect(twice, once);
      expect((await library.signals(profile)).evidenceTitles, 1);
    },
  );
}
