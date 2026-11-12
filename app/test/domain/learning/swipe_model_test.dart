import 'dart:convert';
import 'dart:math';

import 'package:cue/domain/learning/swipe_model.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter_test/flutter_test.dart';

Title t(
  String id, {
  MediaKind kind = MediaKind.anime,
  int? year = 2021,
  List<String> genres = const ['Action'],
  List<String> tags = const [],
  int? score = 84,
  int? episodes = 12,
  int? chapters,
  String status = 'finished',
  String? country = 'JP',
  String? format,
}) => Title(
  id: id,
  kind: kind,
  titleEn: 'Title $id',
  year: year,
  genres: genres,
  tags: tags,
  score: score,
  episodes: episodes,
  chapters: chapters,
  status: status,
  country: country,
  format: format,
);

/// Probability that a random positive outranks a random negative.
double auc(List<double> scores, List<bool> positive) {
  var pairs = 0;
  var wins = 0.0;
  for (var i = 0; i < scores.length; i++) {
    if (!positive[i]) continue;
    for (var j = 0; j < scores.length; j++) {
      if (positive[j]) continue;
      pairs++;
      if (scores[i] > scores[j]) {
        wins += 1;
      } else if (scores[i] == scores[j]) {
        wins += 0.5;
      }
    }
  }
  return pairs == 0 ? 0.5 : wins / pairs;
}

double variance(List<double> xs) {
  final mean = xs.reduce((a, b) => a + b) / xs.length;
  return xs.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
      xs.length;
}

void main() {
  group('swipeFeatures', () {
    test('names the buckets, crosses genres only', () {
      final x = swipeFeatures(
        t('a', genres: ['Action'], tags: ['Isekai'], country: 'kr'),
        seeded: true,
      );
      expect(
        x.keys,
        unorderedEquals([
          'kind:anime',
          'tag:action',
          'tag:isekai',
          'kind:anime|tag:action',
          'year:2020-22',
          'score:80',
          'len:short',
          'country:KR',
          'status:finished',
          'seeded',
        ]),
      );
      for (final e in x.entries) {
        expect(e.value, e.key.contains('tag:') ? 1.0 : swipeMetaValue);
      }
      expect(swipeFeatures(t('a')).containsKey('seeded'), isFalse);
    });

    test('year buckets', () {
      String? bucket(int? year) =>
          swipeFeatures(t('a', year: year)).keys
              .where((k) => k.startsWith('year:'))
              .firstOrNull;
      expect(bucket(1999), 'year:pre2000');
      expect(bucket(2000), 'year:2000s');
      expect(bucket(2009), 'year:2000s');
      expect(bucket(2010), 'year:2010-14');
      expect(bucket(2014), 'year:2010-14');
      expect(bucket(2015), 'year:2015-19');
      expect(bucket(2019), 'year:2015-19');
      expect(bucket(2020), 'year:2020-22');
      expect(bucket(2022), 'year:2020-22');
      expect(bucket(2023), 'year:2023+');
      expect(bucket(null), isNull);
    });

    test('score buckets in steps of 10, none when unknown', () {
      String? bucket(int? score) =>
          swipeFeatures(t('a', score: score)).keys
              .where((k) => k.startsWith('score:'))
              .firstOrNull;
      expect(bucket(70), 'score:70');
      expect(bucket(79), 'score:70');
      expect(bucket(5), 'score:0');
      expect(bucket(100), 'score:90');
      expect(bucket(null), isNull);
    });

    test('length buckets for watching, reading and movies', () {
      String? bucket(Title title) =>
          swipeFeatures(title).keys
              .where((k) => k.startsWith('len:'))
              .firstOrNull;
      expect(bucket(t('a', episodes: 13)), 'len:short');
      expect(bucket(t('a', episodes: 14)), 'len:mid');
      expect(bucket(t('a', episodes: 50)), 'len:mid');
      expect(bucket(t('a', episodes: 51)), 'len:long');
      expect(bucket(t('a', episodes: null)), isNull);
      expect(
        bucket(t('a', kind: MediaKind.movie, episodes: null)),
        'len:short',
      );
      expect(bucket(t('a', format: 'MOVIE', episodes: null)), 'len:short');
      Title manhwa(int? chapters) =>
          t('a', kind: MediaKind.manhwa, episodes: null, chapters: chapters);
      expect(bucket(manhwa(60)), 'len:short');
      expect(bucket(manhwa(61)), 'len:mid');
      expect(bucket(manhwa(200)), 'len:mid');
      expect(bucket(manhwa(201)), 'len:long');
      expect(bucket(manhwa(null)), isNull);
    });

    test('unknown status and country add nothing', () {
      final x = swipeFeatures(t('a', status: 'unknown', country: null));
      expect(x.keys.where((k) => k.startsWith('status:')), isEmpty);
      expect(x.keys.where((k) => k.startsWith('country:')), isEmpty);
    });
  });

  group('featureIdf', () {
    final pool = [
      for (var i = 0; i < 20; i++)
        t('$i', genres: ['Action'], tags: [if (i == 0) 'Time Loop']),
    ];
    final idf = featureIdf(pool);

    test('a tag in every title counts less than a rare one', () {
      expect(idf['action']!, lessThan(idf['time loop']!));
      expect(idf.values, everyElement(allOf(greaterThan(0.0), lessThan(1.01))));
      expect(featureIdf(const []), isEmpty);
    });

    test('swipeFeatures scales tags and crosses by idf', () {
      final x = swipeFeatures(pool.first, idf: idf);
      expect(x['tag:action'], idf['action']);
      expect(x['tag:time loop'], idf['time loop']);
      expect(x['kind:anime|tag:action'], idf['action']);
      expect(x['kind:anime'], swipeMetaValue);
      // A tag the pool never had counts in full.
      final other = swipeFeatures(t('z', genres: ['Mystery']), idf: idf);
      expect(other['tag:mystery'], 1.0);
    });
  });

  group('SwipeModel', () {
    test('starts at 0.5; positives raise and negatives lower', () {
      final model = SwipeModel();
      const liked = {'tag:isekai': 1.0};
      const disliked = {'tag:horror': 1.0};
      expect(model.predict(liked), closeTo(0.5, 1e-9));
      expect(model.predict(const {}), closeTo(0.5, 1e-9));
      expect(model.updates, 0);
      expect(model.confidence, 0);

      for (var i = 0; i < 10; i++) {
        model
          ..update(liked, 1)
          ..update(disliked, 0);
      }
      expect(model.predict(liked), greaterThan(0.6));
      expect(model.predict(disliked), lessThan(0.4));
      expect(model.updates, 20);
      expect(model.confidence, 0.5);
      for (final p in [model.predict(liked), model.predict(disliked)]) {
        expect(p, inInclusiveRange(0, 1));
      }
    });

    test('weight scales the step; zero weight is a no-op', () {
      const x = {'tag:isekai': 1.0};
      final full = SwipeModel()..update(x, 1);
      final weak = SwipeModel()..update(x, 1, weight: 0.1);
      final none = SwipeModel()..update(x, 1, weight: 0);
      expect(full.predict(x), greaterThan(weak.predict(x)));
      expect(weak.predict(x), greaterThan(0.5));
      expect(none.predict(x), closeTo(0.5, 1e-9));
      expect(weak.updates, closeTo(0.1, 1e-12));
      expect(none.updates, 0);
    });

    test('input is normalised: scaling a vector changes nothing', () {
      final model = SwipeModel();
      const x = {'tag:a': 1.0, 'tag:b': 1.0, 'kind:anime': 1.0};
      for (var i = 0; i < 5; i++) {
        model.update(x, 1);
      }
      final scaled = {for (final e in x.entries) e.key: e.value * 7};
      expect(model.predict(scaled), closeTo(model.predict(x), 1e-12));
    });

    test('learns a hidden taste: AUC > 0.8 after 150 swipes', () {
      final vocabulary = [for (var i = 0; i < 40; i++) 'tag$i'];
      final likes = {'tag0', 'tag1', 'tag2'};
      final dislikes = {'tag3', 'tag4', 'tag5'};
      int taste(Title title) =>
          title.features.intersection(likes).length -
          title.features.intersection(dislikes).length;

      // Several seeds, so the bar is not met by one lucky deck.
      for (var seed = 1; seed <= 5; seed++) {
        final random = Random(seed);
        final titles = [
          for (var i = 0; i < 300; i++)
            t(
              '$i',
              genres: const [],
              tags: ([...vocabulary]..shuffle(random)).take(6).toList(),
              year: 1995 + random.nextInt(31),
              score: 50 + random.nextInt(45),
            ),
        ];
        final idf = featureIdf(titles);
        final model = SwipeModel();
        // Saves what leans liked, rejects what leans disliked, and passes
        // on the rest with "Not now".
        for (final title in titles.take(150)) {
          final lean = taste(title);
          final decision = lean > 0
              ? Decision.willTry
              : lean < 0
              ? Decision.notInterested
              : Decision.notNow;
          final teach = decisionLabel(decision)!;
          model.update(
            swipeFeatures(title, idf: idf),
            teach.label,
            weight: teach.weight,
          );
        }

        final heldOut = titles.skip(150).toList();
        expect(heldOut, hasLength(150));
        final score = auc(
          [for (final x in heldOut) model.predict(swipeFeatures(x, idf: idf))],
          [for (final x in heldOut) taste(x) > 0],
        );
        expect(score, greaterThan(0.8), reason: 'seed $seed');

        final top = model.topFeatures(n: 6).map((e) => e.key).toSet();
        expect(
          top.intersection({
            for (final f in [...likes, ...dislikes]) 'tag:$f',
          }).length,
          greaterThanOrEqualTo(4),
          reason: 'seed $seed: $top',
        );
      }
    });

    test('uncertainty falls as updates accumulate', () {
      final model = SwipeModel();
      const x = {'tag:isekai': 1.0, 'kind:anime': 1.0};
      expect(model.uncertainty(x), closeTo(1, 1e-12));
      expect(model.uncertainty(const {}), 1);
      var last = 1.0;
      for (var i = 0; i < 20; i++) {
        model.update(x, i.isEven ? 1 : 0);
        final now = model.uncertainty(x);
        expect(now, lessThan(last));
        last = now;
      }
      expect(last, lessThan(0.1));
      expect(model.uncertainty(const {'tag:never': 1.0}), closeTo(1, 1e-12));
      // Half seen, half unseen sits in between.
      expect(
        model.uncertainty(const {'tag:isekai': 1.0, 'tag:never': 1.0}),
        closeTo((1 + last) / 2, 1e-9),
      );
    });

    test('sample spreads more for unseen features than trained ones', () {
      final model = SwipeModel();
      const trained = {'tag:isekai': 1.0};
      const unseen = {'tag:never': 1.0};
      for (var i = 0; i < 60; i++) {
        model.update(trained, i.isEven ? 1 : 0);
      }
      List<double> draws(Map<String, double> x, int seed) {
        final random = Random(seed);
        return [for (var i = 0; i < 200; i++) model.sample(x, random)];
      }

      final unseenDraws = draws(unseen, 3);
      final trainedDraws = draws(trained, 3);
      expect(variance(unseenDraws), greaterThan(4 * variance(trainedDraws)));
      expect(unseenDraws, everyElement(inInclusiveRange(0, 1)));
      expect(draws(unseen, 3), unseenDraws, reason: 'seeded draws repeat');
      expect(draws(unseen, 4), isNot(unseenDraws));
    });

    test('weights stay bounded under relentless one-sided updates', () {
      final model = SwipeModel(learningRate: 5);
      const x = {'tag:isekai': 1.0};
      for (var i = 0; i < 500; i++) {
        model.update(x, 1);
      }
      expect(model.topFeatures().single.value, inInclusiveRange(-4, 4));
      expect(model.predict(x), lessThan(1));
    });

    test('JSON round trip gives identical predictions', () {
      final random = Random(11);
      final model = SwipeModel(learningRate: 0.2, l2: 0.01, maxFeatures: 50);
      Map<String, double> vector() => {
        for (var i = 0; i < 5; i++)
          'tag:${random.nextInt(30)}': random.nextDouble() + 0.1,
      };
      for (var i = 0; i < 80; i++) {
        model.update(vector(), random.nextBool() ? 1 : 0, weight: 0.3 + i % 3);
      }
      final restored = SwipeModel.fromJson(
        jsonDecode(jsonEncode(model.toJson())) as Map<String, Object?>,
      );
      expect(restored.toJson(), model.toJson());
      expect(restored.toJson()['v'], 1);
      expect(restored.updates, model.updates);
      expect(restored.maxFeatures, 50);
      for (var i = 0; i < 20; i++) {
        final x = vector();
        expect(restored.predict(x), model.predict(x));
        expect(restored.uncertainty(x), model.uncertainty(x));
        expect(restored.sample(x, Random(i)), model.sample(x, Random(i)));
      }
      // And it keeps learning identically.
      final x = vector();
      model.update(x, 1);
      restored.update(x, 1);
      expect(restored.toJson(), model.toJson());
    });

    test('unknown version or malformed JSON gives a fresh model', () {
      final trained = SwipeModel()..update(const {'tag:isekai': 1.0}, 1);
      final good = trained.toJson();
      final bad = <Map<String, Object?>>[
        {},
        {...good, 'v': 2},
        {...good, 'v': '1'},
        {...good, 'bias': 'high'},
        {...good, 'bias': double.nan},
        {...good, 'updates': -1},
        {...good, 'learningRate': 0},
        {...good, 'maxFeatures': 0},
        {...good, 'features': 'none'},
        {...good, 'features': null},
        {
          ...good,
          'features': {
            'tag:isekai': [1.0],
          },
        },
        {
          ...good,
          'features': {
            'tag:isekai': [1.0, 'x', 2.0],
          },
        },
        {
          ...good,
          'features': {
            'tag:isekai': [1.0, double.infinity, 2.0],
          },
        },
        {
          ...good,
          'features': {1: 2},
        },
      ];
      for (final json in bad) {
        final model = SwipeModel.fromJson(json);
        expect(model.updates, 0, reason: '$json');
        expect(model.topFeatures(), isEmpty, reason: '$json');
        expect(
          model.predict(const {'tag:isekai': 1.0}),
          closeTo(0.5, 1e-9),
          reason: '$json',
        );
      }
    });

    test('pruning keeps the map within the cap and the strongest', () {
      final model = SwipeModel(maxFeatures: 50);
      const strong = ['tag:loved', 'tag:hated'];
      for (var i = 0; i < 40; i++) {
        model
          ..update(const {'tag:loved': 1.0}, 1)
          ..update(const {'tag:hated': 1.0}, 0);
      }
      var largest = 0;
      for (var i = 0; i < 400; i++) {
        model.update({
          'tag:noise$i': 1.0,
          'tag:other$i': 1.0,
        }, i.isEven ? 1 : 0);
        final size = (model.toJson()['features']! as Map).length;
        largest = max(largest, size);
      }
      expect(largest, lessThanOrEqualTo(50));
      final kept = (model.toJson()['features']! as Map).keys.toSet();
      expect(kept.length, greaterThanOrEqualTo(45));
      expect(kept, containsAll(strong));
      expect(
        model.topFeatures(n: 2).map((e) => e.key),
        unorderedEquals(strong),
      );
      expect(model.predict(const {'tag:loved': 1.0}), greaterThan(0.6));
      expect(model.predict(const {'tag:hated': 1.0}), lessThan(0.4));
    });

    test('topFeatures orders by |weight| and honours n', () {
      final model = SwipeModel();
      for (var i = 0; i < 10; i++) {
        model.update(const {'a': 1.0}, 0);
      }
      model.update(const {'b': 1.0}, 1);
      final top = model.topFeatures();
      expect(top.map((e) => e.key), ['a', 'b']);
      expect(top.first.value, lessThan(0));
      expect(top.last.value, greaterThan(0));
      expect(model.topFeatures(n: 1), hasLength(1));
      expect(model.topFeatures(n: 0), isEmpty);
    });
  });

  group('labels', () {
    test('decisionLabel', () {
      expect(decisionLabel(Decision.willTry), (label: 1.0, weight: 1.0));
      expect(decisionLabel(Decision.notInterested), (label: 0.0, weight: 1.0));
      expect(decisionLabel(Decision.watched), (label: 1.0, weight: 0.5));
      expect(decisionLabel(Decision.notNow), (label: 0.0, weight: 0.25));
      expect(decisionLabel(Decision.notNow, savingForLater: true), isNull);
      expect(decisionLabel(Decision.willTry, savingForLater: true), (
        label: 1.0,
        weight: 1.0,
      ));
    });

    test('implicitLabel takes the strongest signal only', () {
      const short = Duration(seconds: 2);
      const long = Duration(seconds: 8);
      expect(implicitLabel(dwell: short), isNull);
      expect(implicitLabel(dwell: const Duration(milliseconds: 7999)), isNull);
      expect(implicitLabel(dwell: long), (label: 1.0, weight: 0.1));
      expect(implicitLabel(dwell: short, heldPoster: true), (
        label: 1.0,
        weight: 0.15,
      ));
      expect(implicitLabel(dwell: long, heldPoster: true), (
        label: 1.0,
        weight: 0.15,
      ));
      expect(implicitLabel(dwell: short, openedDetails: true), (
        label: 1.0,
        weight: 0.3,
      ));
      expect(
        implicitLabel(dwell: long, openedDetails: true, heldPoster: true),
        (label: 1.0, weight: 0.3),
      );
    });
  });
}
