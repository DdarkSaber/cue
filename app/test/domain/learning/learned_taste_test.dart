import 'dart:math';

import 'package:cue/domain/learning/learned_taste.dart';
import 'package:cue/domain/learning/swipe_model.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/ranker.dart';
import 'package:flutter_test/flutter_test.dart';

Title _t(String id, List<String> tags, {int score = 70}) => Title(
  id: id,
  kind: MediaKind.anime,
  titleEn: 'Title $id',
  year: 2022,
  genres: tags,
  score: score,
);

void main() {
  final liked = [
    for (var i = 0; i < 30; i++) _t('l$i', ['Action', 'Heist']),
  ];
  final disliked = [
    for (var i = 0; i < 30; i++) _t('d$i', ['Romance', 'School']),
  ];

  LearnedTaste trained() {
    final pool = [...liked, ...disliked];
    final taste = LearnedTaste(SwipeModel(), idf: featureIdf(pool));
    for (var i = 0; i < 25; i++) {
      taste.learn(liked[i], 1, 1);
      taste.learn(disliked[i], 0, 1);
    }
    return taste;
  }

  test('an untrained model leaves the hand-tuned score alone', () {
    final taste = LearnedTaste(SwipeModel());
    expect(taste.blend, 0);
    expect(taste.mix(liked.first, 0.42), 0.42);
  });

  test('calibrated scores spread around an average candidate', () {
    final taste = trained()..calibrate([...liked, ...disliked]);
    expect(taste.likes(liked.last), greaterThan(0.6));
    expect(taste.likes(disliked.last), lessThan(0.4));
    expect(taste.blend, LearnedTaste.maxBlend);
  });

  test('swipes reorder a deal the hand-tuned score had tied', () {
    final taste = trained();
    final pool = [...disliked.skip(25), ...liked.skip(25)];
    final ranker = Ranker(random: Random(1), clock: () => DateTime(2026));
    List<String> deal(LearnedTaste? t) => [
      for (final c in ranker.deal(
        pool,
        const ProfileSignals(),
        const DeckFilters(),
        showAdult: false,
        enabledKinds: {MediaKind.anime},
        titlesById: {for (final x in pool) x.id: x},
        swipeTaste: t,
      ))
        c.title.id,
    ];
    // Exploration cards are interleaved from the third slot on, so the five
    // liked-looking titles fill the top seven rather than the top five.
    final top = deal(taste).take(7);
    expect(top.where((id) => id.startsWith('l')).length, 5);
  });

  test('exploring prefers what the model knows least about', () {
    final taste = trained();
    final unknown = _t('u', ['Mecha', 'Space']);
    final r = Random(3);
    var novel = 0.0;
    var known = 0.0;
    for (var i = 0; i < 200; i++) {
      novel += taste.explore(unknown, r);
      known += taste.explore(disliked.last, r);
    }
    expect(novel, greaterThan(known));
  });
}
