import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/mood/mode_model.dart';
import 'package:cue/domain/mood/mode_tracker.dart';
import 'package:cue/domain/mood/mood_features.dart';
import 'package:cue/domain/mood/sessions.dart';
import 'package:cue/domain/mood/vec.dart';
import 'package:cue/domain/mood/word_model.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;
String _id() => 'm${_n++}';

Vec v(List<String> f) => {for (final x in f) x: 1.0};

const isekai = ['isekai', 'fantasy', 'kind:anime', 'q:low'];
const romcom = ['romance', 'comedy', 'slice of life', 'q:high'];

void main() {
  group('mood features', () {
    test('length, quality, era and country buckets', () {
      const movie = Title(
        id: 'a',
        kind: MediaKind.movie,
        score: 85,
        year: 2020,
      );
      expect(
        moodFeatures(movie),
        containsAll(['kind:movie', 'len:short', 'q:high', 'era:new']),
      );
      const anime = Title(
        id: 'b',
        kind: MediaKind.anime,
        episodes: 24,
        score: 60,
        year: 2005,
        country: 'JP',
      );
      expect(
        moodFeatures(anime),
        containsAll(['len:mid', 'q:low', 'era:classic', 'cc:JP']),
      );
      const manga = Title(id: 'c', kind: MediaKind.manga, chapters: 500);
      expect(lenBucket(manga), 'long');
      const unknown = Title(id: 'd', kind: MediaKind.series);
      expect(lenBucket(unknown), isNull);
    });
  });

  group('vectors', () {
    test('cosine is bounded and topK prunes', () {
      expect(cosine(v(['a', 'b']), v(['a', 'b'])), closeTo(1, 1e-9));
      expect(cosine(v(['a']), v(['b'])), 0);
      expect(cosineSet({'a'}, {}), 0);
      expect(topK({'a': 3, 'b': -5, 'c': 1}, 2).keys, containsAll(['a', 'b']));
    });
  });

  group('sessions', () {
    final t0 = DateTime(2026, 11, 1, 20);
    MoodEvent e(String id, int min, Decision d, {String? rev}) => MoodEvent(
      id: id,
      titleId: 't$id',
      decision: d,
      at: t0.add(Duration(minutes: min)),
      reverses: rev,
    );

    test('a 45-minute gap splits sessions and undo removes the swipe', () {
      final s = splitSessions([
        e('1', 0, Decision.willTry),
        e('2', 5, Decision.notInterested),
        e('3', 6, Decision.willTry, rev: '2'),
        e('4', 60, Decision.watched),
      ]);
      expect(s, hasLength(2));
      expect(s.first.picks.map((p) => p.$1), ['t1']);
      expect(s.last.picks.single.$2, 0.8);
    });

    test('hour buckets', () {
      expect(hourBucket(DateTime(2026, 1, 1, 8)), 0);
      expect(hourBucket(DateTime(2026, 1, 1, 23)), 3);
    });
  });

  group('modes', () {
    final evening = DateTime(2026, 11, 1, 20);

    test('two kinds of sessions make two labelled modes', () {
      final m = ModeModel(null, _id);
      for (var i = 0; i < 3; i++) {
        m.absorb(v(isekai), evening);
        m.absorb(v(romcom), evening);
      }
      expect(m.modes, hasLength(2));
      expect(m.modes.map((x) => x.label).join(' '), contains('Isekai'));
      expect(m.modes.first.sessions, 3);
    });

    test('thin sessions are skipped and a seventh mode merges two', () {
      final m = ModeModel(null, _id);
      m.absorb(v(isekai), evening, positives: 1);
      expect(m.modes, isEmpty);
      for (var i = 0; i < 7; i++) {
        m.absorb(v(['g$i', 'h$i']), evening);
      }
      expect(m.modes, hasLength(ModeModel.maxModes));
    });

    test('a renamed mode keeps its name', () {
      final m = ModeModel(null, _id)..absorb(v(isekai), evening);
      m.modes.first
        ..label = 'Brain off'
        ..userLabel = true;
      m.absorb(v(isekai), evening);
      expect(m.modes.first.label, 'Brain off');
      expect(Mode.fromJson(m.modes.first.toJson()).label, 'Brain off');
    });
  });

  group('tracker', () {
    test('three positive swipes on the other mode switch the guess', () {
      final model = ModeModel(null, _id);
      for (var i = 0; i < 5; i++) {
        model.absorb(v(isekai), DateTime(2026, 11, 1, 23));
      }
      model.absorb(v(romcom), DateTime(2026, 11, 1, 9));
      final t = ModeTracker(model.modes, now: DateTime(2026, 11, 2, 23));
      expect(t.top!.label, contains('Isekai'));
      for (var i = 0; i < 3; i++) {
        t.observe(romcom.toSet(), signalFor(Decision.willTry));
      }
      expect(t.top!.label, contains('Romance'));
      expect(t.p.values.every((x) => x >= ModeTracker.floor - 1e-9), isTrue);
    });

    test('a correction wins immediately', () {
      final model = ModeModel(null, _id)
        ..absorb(v(isekai), DateTime(2026, 1, 1, 20))
        ..absorb(v(romcom), DateTime(2026, 1, 1, 20));
      final t = ModeTracker(model.modes, now: DateTime(2026, 1, 2, 20))
        ..force(model.modes.last.id);
      expect(t.top, model.modes.last);
      expect(t.confidence, 0.9);
    });
  });

  group('words', () {
    test('a word means nothing until used twice, then points at the picks', () {
      final w = WordModel();
      final tokens = tokenize('I want a grind tonight');
      expect(tokens, containsAll(['grind', 'tonight', 'grind tonight']));
      w.learn(tokens, normalize(v(['action', 'len:long'])));
      expect(w.vectorFor(['grind']), isEmpty);
      w.learn(tokens, normalize(v(['action', 'len:long'])));
      expect(
        cosineSet({'action', 'len:long'}, w.vectorFor(['grind'])),
        greaterThan(0.9),
      );
    });
  });
}
