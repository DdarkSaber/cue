import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/outcome_stats_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/decisions.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late CueDatabase db;
  late DecisionService decisions;
  late OutcomeStatsRepository stats;
  late CatalogRepository catalog;
  late String profile;
  late DateTime now;

  Future<Title> title(int id) async =>
      (await catalog.titleById('anilist:$id'))!;

  Future<void> decide(
    int id,
    Decision d, {
    DeckContext context = DeckContext.deck,
  }) async {
    await decisions.decide(profile, await title(id), d, context: context);
    now = now.add(const Duration(minutes: 1));
  }

  setUp(() async {
    now = DateTime(2026, 11, 10, 12);
    db = memoryDb();
    decisions = DecisionService(db, clock: () => now);
    profile = (await ProfileRepository(db, clock: () => now).ensureActive()).id;
    catalog = CatalogRepository(db, FakeGateway(), clock: () => now);
    stats = OutcomeStatsRepository(db, catalog, clock: () => now);
    await catalog.upsert([
      for (var i = 1; i <= 8; i++) CatalogItemDto(item(i)),
      for (var i = 11; i <= 14; i++)
        CatalogItemDto(item(i, kind: 'manhwa', country: 'KR')),
    ]);
  });

  tearDown(() => db.close());

  /// Day one: anime 1 saved, 2 rejected, 3 watched, 4 not now; manhwa 11
  /// saved, 12 read. Day two: anime 5 saved, manhwa 13 rejected, anime 6
  /// saved then undone, anime 7 saved from a revisit (not the deck).
  Future<void> seed() async {
    await decide(1, Decision.willTry);
    await decide(2, Decision.notInterested);
    await decide(3, Decision.watched);
    await decide(4, Decision.notNow);
    await decide(11, Decision.willTry);
    await decide(12, Decision.watched);
    now = DateTime(2026, 11, 11, 9);
    await decide(5, Decision.willTry);
    await decide(13, Decision.notInterested);
    await decide(6, Decision.willTry);
    expect((await decisions.undoLast(profile))!.titleId, 'anilist:6');
    now = now.add(const Duration(minutes: 1));
    await decide(7, Decision.willTry, context: DeckContext.revisit);
  }

  test('nothing decided gives empty stats', () async {
    final s = await stats.stats(profile);
    expect(s.saved, 0);
    expect(s.decided, 0);
    expect(s.saveRate, 0);
    expect(s.byKind, isEmpty);
    expect(await stats.daily(profile), isEmpty);
    expect(await stats.replayEvents(profile), isEmpty);
  });

  test('counts deck decisions, leaving out undone and revisit ones', () async {
    await seed();
    final s = await stats.stats(profile);
    expect(s.saved, 3);
    expect(s.notInterested, 2);
    expect(s.watched, 2);
    expect(s.notNow, 1);
    expect(s.decided, 7);
    expect(s.saveRate, 3 / 5);
    expect(s.byKind, {
      MediaKind.anime: (saved: 2, rejected: 1),
      MediaKind.manhwa: (saved: 1, rejected: 1),
    });
  });

  test('last, skip and since pick the window', () async {
    await seed();
    // Newest standing deck decisions: 13 rejected, 5 saved, 12 read, ...
    final newest = await stats.stats(profile, last: 2);
    expect((newest.saved, newest.notInterested), (1, 1));
    expect(newest.byKind, {
      MediaKind.anime: (saved: 1, rejected: 0),
      MediaKind.manhwa: (saved: 0, rejected: 1),
    });

    final before = await stats.stats(profile, last: 3, skip: 2);
    expect(
      (before.saved, before.notInterested, before.watched, before.notNow),
      (1, 0, 1, 1),
    );

    final rest = await stats.stats(profile, skip: 6);
    expect((rest.saved, rest.notInterested), (1, 1));

    final dayTwo = await stats.stats(profile, since: DateTime(2026, 11, 11));
    expect((dayTwo.saved, dayTwo.notInterested, dayTwo.watched), (1, 1, 0));
  });

  test('another profile sees nothing', () async {
    await seed();
    final other = await ProfileRepository(
      db,
      clock: () => now,
    ).create(displayName: 'B');
    expect((await stats.stats(other.id)).decided, 0);
    expect(await stats.replayEvents(other.id), isEmpty);
  });

  test('daily groups saved and rejected by local day, oldest first', () async {
    await seed();
    expect(await stats.daily(profile), [
      (day: DateTime(2026, 11, 10), saved: 2, rejected: 1),
      (day: DateTime(2026, 11, 11), saved: 1, rejected: 1),
    ]);
    // A one-day window is today only.
    expect(await stats.daily(profile, days: 1), [
      (day: DateTime(2026, 11, 11), saved: 1, rejected: 1),
    ]);
    // Days fall out of the window as time passes.
    now = DateTime(2026, 11, 24, 23);
    expect(await stats.daily(profile), [
      (day: DateTime(2026, 11, 11), saved: 1, rejected: 1),
    ]);
  });

  test('replayEvents carries labels, weights and time order', () async {
    await seed();
    final events = await stats.replayEvents(profile);
    expect(
      [for (final e in events) (e.title.id, e.label, e.weight)],
      [
        ('anilist:1', 1.0, 1.0),
        ('anilist:2', 0.0, 1.0),
        ('anilist:3', 1.0, 0.5),
        ('anilist:4', 0.0, 0.25),
        ('anilist:11', 1.0, 1.0),
        ('anilist:12', 1.0, 0.5),
        ('anilist:5', 1.0, 1.0),
        ('anilist:13', 0.0, 1.0),
      ],
    );
    expect(events.first.at, DateTime(2026, 11, 10, 12));
    expect(events.first.title.kind, MediaKind.anime);
    expect(events[4].title.kind, MediaKind.manhwa);
    for (var i = 1; i < events.length; i++) {
      expect(events[i].at.isBefore(events[i - 1].at), isFalse);
    }

    // The limit keeps the newest, still oldest first.
    final newest = await stats.replayEvents(profile, limit: 2);
    expect([for (final e in newest) e.title.id], ['anilist:5', 'anilist:13']);
  });

  test('decisions in the same second keep the order they were made', () async {
    final t = [await title(1), await title(2), await title(3)];
    await decisions.decide(profile, t[0], Decision.willTry);
    await decisions.decide(profile, t[1], Decision.notInterested);
    await decisions.decide(profile, t[2], Decision.willTry);
    final events = await stats.replayEvents(profile);
    expect(
      [for (final e in events) e.title.id],
      ['anilist:1', 'anilist:2', 'anilist:3'],
    );
    final newest = await stats.stats(profile, last: 1);
    expect((newest.saved, newest.notInterested), (1, 0));
  });
}
