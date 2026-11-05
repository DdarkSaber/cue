import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_rating_service.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/recommendation_repository.dart';
import 'package:cue/data/try_now_repository.dart';
import 'package:cue/domain/models/library.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:cue/domain/ranker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  group('Library rating service', () {
    late CueDatabase db;
    late LibraryRepository library;
    late RecommendationRepository recommendations;
    late LibraryRatingService service;
    final now = DateTime.utc(2026, 10, 20, 12);
    final watched500DaysAgo = recencyWeight(
      now.subtract(const Duration(days: 500)),
      now,
    );

    Future<UserTitle?> row(String profile, String title) =>
        (db.select(db.userTitles)..where(
              (u) => u.profileId.equals(profile) & u.titleId.equals(title),
            ))
            .getSingleOrNull();

    Future<void> seed(
      String title, {
      String profile = 'a',
      String state = 'completed',
      String? rating,
      bool entry = true,
      Duration? shortlistAge,
    }) async {
      await db
          .into(db.catalogTitles)
          .insertOnConflictUpdate(
            CatalogTitlesCompanion.insert(
              id: title,
              mediaKind: 'anime',
              titleEn: Value('Invented $title'),
              genresJson: const Value('["Comedy"]'),
              updatedAt: now,
            ),
          );
      if (entry) {
        await db
            .into(db.userTitles)
            .insert(
              UserTitlesCompanion.insert(
                profileId: profile,
                titleId: title,
                state: Value(state),
                rating: Value(rating),
                rewatchMood: const Value('comfort'),
                progressUnit: const Value('episode'),
                progressValue: const Value(4.5),
                latestKnown: const Value(12),
                actualWatchedAt: Value(now.subtract(const Duration(days: 500))),
                note: const Value('Synthetic note; do not replace'),
                source: const Value('import:synthetic-batch'),
                updatedAt: now.subtract(const Duration(days: 1)),
              ),
            );
      }
      if (shortlistAge != null) {
        await db
            .into(db.shortlist)
            .insert(
              ShortlistCompanion.insert(
                profileId: profile,
                titleId: title,
                addedAt: now.subtract(shortlistAge),
              ),
            );
      }
    }

    setUp(() async {
      db = memoryDb();
      for (final id in ['a', 'b']) {
        await db
            .into(db.profiles)
            .insert(ProfilesCompanion.insert(id: id, createdAt: now));
      }
      library = LibraryRepository(db, clock: () => now);
      recommendations = RecommendationRepository(db, clock: () => now);
      service = LibraryRatingService(
        db,
        library,
        recommendations,
        clock: () => now,
      );
    });
    tearDown(() async => db.close());

    test('unrated and planned are never fabricated ratings; only tried entries eligible', () async {
      await seed('seen', state: 'seen');
      await seed('planned', state: 'planned');
      await seed('unknown', state: 'none');
      await seed('rated', rating: Rating.once.code);
      expect((await service.candidates('a')).map((c) => c.title.id), ['seen']);
      expect((await row('a', 'planned'))!.rating, isNull);
      expect((await row('a', 'unknown'))!.rating, isNull);
      expect((await library.signals('b')).weights, isEmpty);
    });

    test('Loved Enjoyed One-time Dropped use existing numeric evidence and preserve every field', () async {
      for (final rating in [
        Rating.favourite,
        Rating.enjoyed,
        Rating.once,
        Rating.dropped,
      ]) {
        await seed('one');
        final before = (await row('a', 'one'))!;
        final candidate = (await service.candidates('a')).single;
        final undo = await service.rate('a', candidate, rating);
        final after = (await row('a', 'one'))!;
        expect(after.rating, rating.code);
        expect(
          after.copyWith(
            rating: Value(before.rating),
            updatedAt: before.updatedAt,
          ),
          before,
        );
        // Imported history counts by recency: this one was watched 500
        // days ago.
        expect(
          (await library.signals('a')).weights['comedy'],
          closeTo(rating.weight * watched500DaysAgo, 1e-9),
        );
        expect(after.updatedAt.isAfter(before.updatedAt), isTrue);
        expect(await service.undo('a', undo), isTrue);
        final restored = (await row('a', 'one'))!;
        expect(restored.copyWith(updatedAt: before.updatedAt), before);
        expect(restored.updatedAt.isAfter(after.updatedAt), isTrue);
        expect(
          (await library.signals('a')).weights['comedy'],
          closeTo(0.15 * watched500DaysAgo, 1e-9),
        );
        await (db.delete(
          db.userTitles,
        )..where((u) => u.titleId.equals('one'))).go();
      }
      expect(
        [
          Rating.favourite.weight,
          Rating.enjoyed.weight,
          Rating.once.weight,
          Rating.dropped.weight,
        ],
        [3, 2, 1.5, -1.5],
      );
    });

    test('deliberate Enjoyed is positive evidence without invented rewatch intent; legacy intent preserved', () async {
      await seed('one');
      await seed('legacy', rating: Rating.wouldRewatch.code);
      final legacy = (await row('a', 'legacy'))!;
      final token = await service.rate(
        'a',
        (await service.candidates('a')).single,
        Rating.enjoyed,
      );
      final entry = (await library.entry('a', 'one'))!;
      expect(entry.rating, Rating.enjoyed);
      expect(entry.rating!.weight, 2);
      expect(entry.rating!.isRewatch, isFalse);
      expect(Rating.parse((await row('a', 'one'))!.rating)!.isRewatch, isFalse);
      expect(await row('a', 'legacy'), legacy);
      expect((await library.entry('a', 'legacy'))!.rating!.isRewatch, isTrue);
      expect(await service.undo('a', token), isTrue);
      expect(await row('a', 'legacy'), legacy);
    });

    test('tried follow-up clears Try now, Undo restores intent; concurrent marker change blocks Undo', () async {
      await seed(
        'one',
        state: 'planned',
        shortlistAge: const Duration(days: 8),
      );
      final priority = TryNowRepository(db, clock: () => now);
      await db.transaction(() => priority.setInTransaction('a', 'one', true));
      final candidate = (await service.candidates('a', followUp: true)).single;
      await service.answer('a', candidate, FollowUpAnswer.haventStarted);
      expect(await priority.isActive('a', 'one'), isTrue);
      expect(await db.select(db.shortlist).get(), hasLength(1));
      final token = (await service.answer(
        'a',
        candidate,
        FollowUpAnswer.notForMe,
      ))!;
      expect(await priority.isActive('a', 'one'), isFalse);
      expect(await service.undo('a', token), isTrue);
      expect(await priority.isActive('a', 'one'), isTrue);
      final fresh = (await service.candidates(
        'a',
        followUp: true,
        includeDismissed: true,
      )).single;
      final second = (await service.answer(
        'a',
        fresh,
        FollowUpAnswer.enjoyed,
      ))!;
      await db.transaction(() => priority.setInTransaction('a', 'one', true));
      expect(await service.undo('a', second), isFalse);
      expect(await db.select(db.shortlist).get(), isEmpty);
      expect((await row('a', 'one'))!.rating, Rating.enjoyed.code);
    });

    test(
      'rated overwrite is deliberate and Undo restores exact previous rating',
      () async {
        await seed('one', rating: Rating.okay.code);
        final candidate = (await service.candidates(
          'a',
          includeRated: true,
        )).single;
        await expectLater(
          service.rate('a', candidate, Rating.favourite),
          throwsA(isA<RatingConflict>()),
        );
        expect((await row('a', 'one'))!.rating, Rating.okay.code);
        final token = await service.rate(
          'a',
          candidate,
          Rating.favourite,
          overwrite: true,
        );
        expect(await service.undo('a', token), isTrue);
        expect((await row('a', 'one'))!.rating, Rating.okay.code);
        expect(await service.undo('a', token), isFalse);
      },
    );

    test('stale card and concurrent Undo refuse overwriting even unchanged timestamp', () async {
      await seed('one');
      final candidate = (await service.candidates('a')).single;
      await (db.update(
        db.userTitles,
      )..where((u) => u.titleId.equals('one'))).write(
        const UserTitlesCompanion(note: Value('Concurrent synthetic edit')),
      );
      await expectLater(
        service.rate('a', candidate, Rating.favourite),
        throwsA(isA<RatingConflict>()),
      );
      final token = await service.rate(
        'a',
        (await service.candidates('a')).single,
        Rating.favourite,
      );
      await (db.update(db.userTitles)..where((u) => u.titleId.equals('one')))
          .write(const UserTitlesCompanion(progressValue: Value(9)));
      expect(await service.undo('a', token), isFalse);
      expect((await row('a', 'one'))!.progressValue, 9);
      expect((await row('a', 'one'))!.rating, Rating.favourite.code);
    });

    test(
      'profile boundaries reject foreign snapshots and foreign Undo tokens',
      () async {
        await seed('shared');
        await seed('shared', profile: 'b', rating: Rating.dropped.code);
        final candidate = (await service.candidates('a')).single;
        await expectLater(
          service.rate('b', candidate, Rating.favourite, overwrite: true),
          throwsA(isA<RatingConflict>()),
        );
        final token = await service.rate('a', candidate, Rating.once);
        expect(await service.undo('b', token), isFalse);
        expect((await row('b', 'shared'))!.rating, Rating.dropped.code);
        expect((await recommendations.read('b')), isEmpty);
      },
    );

    test('follow-up only older than seven days, unrated, undismissed and this profile', () async {
      await seed('old', entry: false, shortlistAge: const Duration(days: 8));
      await seed(
        'boundary',
        entry: false,
        shortlistAge: const Duration(days: 7),
      );
      await seed('new', entry: false, shortlistAge: const Duration(days: 2));
      await seed(
        'dismissed',
        entry: false,
        shortlistAge: const Duration(days: 9),
      );
      await seed(
        'rated',
        rating: Rating.once.code,
        shortlistAge: const Duration(days: 8),
      );
      await seed(
        'foreign',
        profile: 'b',
        entry: false,
        shortlistAge: const Duration(days: 8),
      );
      await service.dismiss('a', 'dismissed');
      expect(
        (await service.candidates('a', followUp: true)).map((c) => c.title.id),
        ['old'],
      );
      expect(
        (await service.candidates(
          'a',
          followUp: true,
          includeDismissed: true,
        )).map((c) => c.title.id).toSet(),
        {'old', 'dismissed'},
      );
    });

    test("Haven't started and dismissal never add ratings, consumption or evidence", () async {
      await seed(
        'one',
        state: 'planned',
        shortlistAge: const Duration(days: 8),
      );
      final before = (await row('a', 'one'))!;
      await library.recomputeWeights('a');
      final shortlistBefore = await db.select(db.shortlist).get();
      final weights = (await library.signals('a')).weights;
      final answer = await service.answer(
        'a',
        (await service.candidates('a', followUp: true)).single,
        FollowUpAnswer.haventStarted,
      );
      expect(answer, isNull);
      expect(await row('a', 'one'), before);
      expect(await db.select(db.shortlist).get(), shortlistBefore);
      expect((await library.signals('a')).weights, weights);
      expect(await recommendations.dismissed('a', 'one'), isTrue);
      expect((await recommendations.read('a'))['followupAnswers'], isNull);
      expect((await recommendations.read('b')), isEmpty);
      await seed('two', entry: false, shortlistAge: const Duration(days: 8));
      final beforeDismiss = await db.select(db.shortlist).get();
      await service.dismiss('a', 'two');
      expect(await row('a', 'two'), isNull);
      expect(await db.select(db.shortlist).get(), beforeDismiss);
    });

    test('meaningful follow-up answers save real ratings without invented consumption', () async {
      final answers = [
        (FollowUpAnswer.loved, Rating.favourite),
        (FollowUpAnswer.enjoyed, Rating.enjoyed),
        (FollowUpAnswer.notForMe, Rating.dropped),
      ];
      for (var i = 0; i < answers.length; i++) {
        final id = 'answer$i';
        await seed(id, state: 'planned', shortlistAge: const Duration(days: 8));
        final before = (await row('a', id))!;
        final shortlistBefore = await (db.select(
          db.shortlist,
        )..where((s) => s.titleId.equals(id))).getSingle();
        final candidate = (await service.candidates(
          'a',
          followUp: true,
        )).single;
        final token = (await service.answer('a', candidate, answers[i].$1))!;
        final after = (await row('a', id))!;
        expect(
          after.copyWith(
            rating: Value(before.rating),
            updatedAt: before.updatedAt,
          ),
          before,
        );
        expect(after.rating, answers[i].$2.code);
        if (answers[i].$1 == FollowUpAnswer.enjoyed) {
          expect(Rating.parse(after.rating)!.isRewatch, isFalse);
        }
        expect(
          await (db.select(
            db.shortlist,
          )..where((s) => s.titleId.equals(id))).get(),
          isEmpty,
        );
        expect(await recommendations.dismissed('a', id), isTrue);
        expect(await service.undo('a', token), isTrue);
        expect(
          await (db.select(
            db.shortlist,
          )..where((s) => s.titleId.equals(id))).getSingle(),
          shortlistBefore,
        );
      }
      final state = await recommendations.read('a');
      expect(state['followupAnswers'], 3);
      expect(state['enjoyed'], 2);
    });

    test('negative tried answer removes Will try; concurrent re-add blocks entire Undo', () async {
      await seed(
        'one',
        state: 'planned',
        shortlistAge: const Duration(days: 8),
      );
      final candidate = (await service.candidates('a', followUp: true)).single;
      final token = (await service.answer(
        'a',
        candidate,
        FollowUpAnswer.notForMe,
      ))!;
      expect(await db.select(db.shortlist).get(), isEmpty);
      expect((await row('a', 'one'))!.rating, Rating.dropped.code);
      expect(
        (await library.signals('a')).weights['comedy'],
        closeTo(-1.5 * watched500DaysAgo, 1e-9),
      );
      final concurrent = ShortlistCompanion.insert(
        profileId: 'a',
        titleId: 'one',
        addedAt: now,
      );
      await db.into(db.shortlist).insert(concurrent);
      final readded = await db.select(db.shortlist).getSingle();
      expect(await service.undo('a', token), isFalse);
      expect(await db.select(db.shortlist).getSingle(), readded);
      expect((await row('a', 'one'))!.rating, Rating.dropped.code);
      await (db.delete(
        db.shortlist,
      )..where((s) => s.titleId.equals('one'))).go();
      await db
          .into(db.decisionEvents)
          .insert(
            DecisionEventsCompanion.insert(
              id: 'synthetic-concurrent-choice',
              profileId: 'a',
              titleId: 'one',
              action: 'not_now',
              createdAt: now,
            ),
          );
      expect(await service.undo('a', token), isFalse);
      expect(await db.select(db.shortlist).get(), isEmpty);
    });

    test('stale shortlist snapshot refuses answer; rated follow-up overwrite requires deliberate guard', () async {
      await seed(
        'one',
        rating: Rating.disliked.code,
        shortlistAge: const Duration(days: 8),
      );
      expect(await service.candidates('a', followUp: true), isEmpty);
      final candidate = (await service.candidates(
        'a',
        followUp: true,
        includeRated: true,
      )).single;
      final before = (await row('a', 'one'))!;
      await expectLater(
        service.answer('a', candidate, FollowUpAnswer.loved),
        throwsA(isA<RatingConflict>()),
      );
      expect((await row('a', 'one'))!, before);
      expect(await db.select(db.shortlist).get(), hasLength(1));
      final token = (await service.answer(
        'a',
        candidate,
        FollowUpAnswer.notForMe,
        overwrite: true,
      ))!;
      expect(await db.select(db.shortlist).get(), isEmpty);
      expect(await service.undo('a', token), isTrue);
      expect(
        (await row('a', 'one'))!.copyWith(updatedAt: before.updatedAt),
        before,
      );
      expect(await db.select(db.shortlist).getSingle(), candidate.shortlist);
      final fresh = (await service.candidates(
        'a',
        followUp: true,
        includeRated: true,
        includeDismissed: true,
      )).single;
      await (db.update(
        db.shortlist,
      )..where((s) => s.titleId.equals('one'))).write(
        ShortlistCompanion(
          addedAt: Value(now.subtract(const Duration(days: 9))),
        ),
      );
      await expectLater(
        service.answer('a', fresh, FollowUpAnswer.loved, overwrite: true),
        throwsA(isA<RatingConflict>()),
      );
      expect((await row('a', 'one'))!.rating, Rating.disliked.code);
    });

    test('new follow-up rating Undo removes new row with sync tombstone and permits fresh deliberate retry', () async {
      await seed('one', entry: false, shortlistAge: const Duration(days: 8));
      final original = (await service.candidates('a', followUp: true)).single;
      final token = (await service.answer(
        'a',
        original,
        FollowUpAnswer.enjoyed,
      ))!;
      final after = (await row('a', 'one'))!;
      expect(after.state, 'none');
      expect(after.actualWatchedAt, isNull);
      expect(after.progressValue, isNull);
      expect(await service.undo('a', token), isTrue);
      expect(await row('a', 'one'), isNull);
      expect(
        (await library.removedAt('a', 'one'))!.isAfter(after.updatedAt),
        isTrue,
      );
      await expectLater(
        service.answer('a', original, FollowUpAnswer.loved),
        throwsA(isA<RatingConflict>()),
      );
      final fresh = (await service.candidates(
        'a',
        followUp: true,
        includeDismissed: true,
      )).single;
      await service.answer('a', fresh, FollowUpAnswer.loved);
      expect((await row('a', 'one'))!.rating, Rating.favourite.code);
      expect(await library.removedAt('a', 'one'), isNull);
    });
  });
}
