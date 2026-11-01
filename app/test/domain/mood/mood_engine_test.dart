import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/mood/mode_model.dart';
import 'package:cue/domain/mood/mood_engine.dart';
import 'package:cue/domain/mood/sessions.dart';
import 'package:cue/domain/mood/word_model.dart';
import 'package:cue/domain/ranker.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStore implements MoodStore {
  (List<Mode>, WordModel)? saved;
  final history = <MoodEvent>[];
  final ended = <MoodSession>[];

  @override
  Future<(List<Mode>, WordModel)?> load(String profileId) async => saved;
  @override
  Future<void> save(String p, List<Mode> modes, WordModel words) async =>
      saved = (List.of(modes), words);
  @override
  Future<List<MoodEvent>> events(String p) async => history;
  @override
  Future<void> sessionEnded(
    String p,
    MoodSession s, {
    String? typed,
    String? modeId,
  }) async => ended.add(s);
}

Title isekai(int i) => Title(
  id: 'i$i',
  kind: MediaKind.anime,
  genres: const ['Fantasy', 'Isekai'],
  episodes: 12,
  score: 60,
);
Title romcom(int i) => Title(
  id: 'r$i',
  kind: MediaKind.anime,
  genres: const ['Romance', 'Comedy'],
  episodes: 12,
  score: 85,
);

void main() {
  final titles = {
    for (var i = 0; i < 20; i++) ...{'i$i': isekai(i), 'r$i': romcom(i)},
  };
  Future<List<Title>> byIds(Iterable<String> ids) async => [
    for (final id in ids)
      if (titles[id] != null) titles[id]!,
  ];

  test(
    'learns two modes from history and follows a switch in 3 swipes',
    () async {
      final store = MemoryStore();
      final night = DateTime(2026, 10, 1, 23);
      // Five late-night isekai sessions, one morning rom-com session.
      for (var d = 0; d < 5; d++) {
        for (var k = 0; k < 3; k++) {
          store.history.add(
            MoodEvent(
              id: 'e$d$k',
              titleId: 'i${d * 3 + k}',
              decision: Decision.willTry,
              at: night.add(Duration(days: d, minutes: k)),
            ),
          );
        }
      }
      for (var k = 0; k < 3; k++) {
        store.history.add(
          MoodEvent(
            id: 'm$k',
            titleId: 'r$k',
            decision: Decision.willTry,
            at: DateTime(2026, 10, 9, 9, k),
          ),
        );
      }
      final engine = MoodEngine(store, 'p', byIds);
      await engine.load();
      expect(engine.modes, hasLength(2));

      engine.startSession(now: DateTime(2026, 10, 20, 23));
      expect(engine.target.label, contains('Isekai'));
      for (var k = 10; k < 13; k++) {
        engine.onSwipe(romcom(k), Decision.willTry);
      }
      expect(engine.target.label, contains('Romance'));

      // The ranker now puts rom-coms first in the default deck.
      final ranker = Ranker();
      const f = DeckFilters();
      final scoreR = ranker.score(
        romcom(15),
        const ProfileSignals(),
        f,
        target: engine.target,
      );
      final scoreI = ranker.score(
        isekai(15),
        const ProfileSignals(),
        f,
        target: engine.target,
      );
      expect(scoreR, greaterThan(scoreI));

      await engine.endSession();
      expect(store.ended.single.positives, 3);
      expect(store.saved, isNotNull);
    },
  );

  test('every 5th card comes from the runner-up mode', () {
    final second = Mode(id: 'x', centroid: {'romance': 1.0, 'comedy': 1.0});
    final cards = [
      for (var i = 0; i < 9; i++) RankedCard(isekai(i), 1 - i / 10, ''),
      RankedCard(romcom(1), 0.01, ''),
    ];
    final out = diversify(cards, second);
    expect(out[4].title.id, 'r1');
    expect(out, hasLength(cards.length));
    expect(diversify(cards, null), same(cards));
  });

  test('AI hints steer the target and an undo is forgotten', () async {
    final engine = MoodEngine(MemoryStore(), 'p', byIds);
    await engine.load();
    engine.startSession(
      now: DateTime(2026, 10, 20, 20),
      text: 'cosy',
      hints: (const ['romance'], const ['horror']),
    );
    expect(engine.target.vec['romance'], greaterThan(0));
    expect(engine.target.vec['horror'], lessThan(0));

    engine.onSwipe(romcom(1), Decision.willTry);
    engine.undo('r1');
    await engine.endSession();
    // Nothing left to learn from after the undo.
    expect(engine.modes, isEmpty);
  });

  test('after forget, ending the session writes nothing back', () async {
    final store = MemoryStore();
    final engine = MoodEngine(store, 'p', byIds);
    await engine.load();
    engine.startSession(now: DateTime(2026, 10, 20, 20));
    for (var k = 0; k < 3; k++) {
      engine.onSwipe(romcom(k), Decision.willTry);
    }
    store.saved = null;
    engine.forget();
    await engine.endSession();
    expect(store.saved, isNull);
    expect(engine.modes, isEmpty);
  });
}
