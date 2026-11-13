import 'dart:math';

import 'package:cue/domain/learning/replay.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter_test/flutter_test.dart';

/// Titles tagged 'good' are the ones the synthetic person saves.
Title _title(int i, {required bool good}) =>
    Title(id: 'test:$i', kind: MediaKind.anime, tags: [if (good) 'good']);

ReplayEvent _event(int i, {required bool good, double weight = 1}) =>
    ReplayEvent(
      _title(i, good: good),
      good ? 1 : 0,
      weight: weight,
      at: DateTime(2026, 11, 1).add(Duration(minutes: i)),
    );

/// Knows the answer from the title alone.
class _Oracle implements ReplayScorer {
  @override
  double predict(Title t) => t.tags.contains('good') ? 0.9 : 0.1;
  @override
  void learn(Title t, double label, double weight) {}
}

/// Records the order of calls.
class _Recorder implements ReplayScorer {
  final log = <String>[];
  @override
  double predict(Title t) {
    log.add('predict ${t.id}');
    return 0.5;
  }

  @override
  void learn(Title t, double label, double weight) =>
      log.add('learn ${t.id} $label $weight');
}

void main() {
  group('auc', () {
    test('perfect, inverted and mixed orderings', () {
      expect(auc([0.1, 0.2, 0.8, 0.9], [0, 0, 1, 1]), 1);
      expect(auc([0.9, 0.8, 0.2, 0.1], [0, 0, 1, 1]), 0);
      // Positives 0.8 and 0.3, negatives 0.5 and 0.1: 3 of 4 pairs correct.
      expect(auc([0.8, 0.3, 0.5, 0.1], [1, 1, 0, 0]), 0.75);
    });

    test('a tie counts as half a win', () {
      // Pairs: (0.5 vs 0.5) half, (0.5 vs 0.2) win, (0.9 vs both) two wins.
      expect(auc([0.5, 0.9, 0.5, 0.2], [1, 1, 0, 0]), closeTo(3.5 / 4, 1e-12));
      // Everything tied tells nothing.
      expect(auc([0.4, 0.4, 0.4, 0.4, 0.4], [1, 0, 1, 0, 0]), 0.5);
    });

    test('is 0.5 when a class is missing or there is no data', () {
      expect(auc([0.1, 0.9], [1, 1]), 0.5);
      expect(auc([0.1, 0.9], [0, 0]), 0.5);
      expect(auc([], []), 0.5);
    });

    test('rejects mismatched lengths', () {
      expect(() => auc([0.1], [1, 0]), throwsArgumentError);
    });
  });

  group('replay', () {
    test('a scorer that knows the truth gets AUC 1', () {
      final events = [for (var i = 0; i < 60; i++) _event(i, good: i % 3 == 0)];
      final report = replay(events, _Oracle());
      expect(report.events, 40);
      expect(report.positives, 13);
      expect(report.baseRate, closeTo(13 / 40, 1e-12));
      expect(report.auc, 1);
      expect(report.precisionAt10, 1);
      // Every prediction is 0.9 for the right class.
      expect(report.logLoss, closeTo(0.10536, 1e-4));
    });

    test('ConstantScorer cannot tell cards apart', () {
      final random = Random(7);
      final events = [
        for (var i = 0; i < 2000; i++) _event(i, good: random.nextBool()),
      ];
      final report = replay(events, ConstantScorer());
      expect(report.auc, closeTo(0.5, 0.05));
      expect(report.baseRate, closeTo(0.5, 0.05));
      // Close to ln 2, the loss of always saying one half.
      expect(report.logLoss, closeTo(0.6931, 0.01));
    });

    test('ConstantScorer predicts the running base rate', () {
      final scorer = ConstantScorer();
      final t = _title(0, good: true);
      expect(scorer.predict(t), 0.5);
      scorer
        ..learn(t, 1, 1)
        ..learn(t, 0, 1)
        ..learn(t, 0, 2);
      expect(scorer.predict(t), 0.25);
    });

    test('warmup events train but are not scored', () {
      final recorder = _Recorder();
      final events = [for (var i = 0; i < 5; i++) _event(i, good: i.isEven)];
      final report = replay(events, recorder, warmup: 3);
      expect(report.events, 2);
      expect(report.positives, 1);
      expect(recorder.log, [
        'learn test:0 1.0 1.0',
        'learn test:1 0.0 1.0',
        'learn test:2 1.0 1.0',
        'predict test:3',
        'learn test:3 0.0 1.0',
        'predict test:4',
        'learn test:4 1.0 1.0',
      ]);
    });

    test('fewer events than the warmup score nothing', () {
      final report = replay([_event(0, good: true)], _Oracle());
      expect(report.events, 0);
      expect(report.auc, 0.5);
      expect(report.logLoss, 0);
      expect(report.precisionAt10, 0);
      expect(report.baseRate, 0);
    });

    test('events are sorted by time, equal times keeping their order', () {
      final recorder = _Recorder();
      final same = DateTime(2026, 11, 2);
      final events = [
        _event(3, good: true),
        _event(1, good: false),
        ReplayEvent(_title(8, good: true), 1, at: same),
        ReplayEvent(_title(9, good: true), 1, at: same),
        _event(2, good: true),
      ];
      replay(events, recorder, warmup: 0);
      expect(recorder.log.where((l) => l.startsWith('predict')).toList(), [
        'predict test:1',
        'predict test:2',
        'predict test:3',
        'predict test:8',
        'predict test:9',
      ]);
      // The caller's list is left as given.
      expect(events.first.title.id, 'test:3');
    });

    test('precisionAt10 looks at the top 3 of each full window of 10', () {
      // Window one: the oracle's top three are all saved. Window two holds a
      // single saved card, so one of its top three is right. The trailing
      // five events do not make a window.
      final events = [
        for (var i = 0; i < 10; i++) _event(i, good: i < 4),
        for (var i = 10; i < 20; i++) _event(i, good: i == 15),
        for (var i = 20; i < 25; i++) _event(i, good: true),
      ];
      final report = replay(events, _Oracle(), warmup: 0);
      expect(report.precisionAt10, closeTo((1 + 1 / 3) / 2, 1e-12));
    });

    test('log loss counts each event by its weight and clips', () {
      // A scorer that is certain and wrong on the heavy event only.
      final events = [
        _event(0, good: true, weight: 3),
        _event(1, good: false, weight: 1),
      ];
      final report = replay(events, _AlwaysZero(), warmup: 0);
      expect(report.logLoss.isFinite, isTrue);
      // -ln(1e-6) on weight 3, about 0 on weight 1.
      expect(report.logLoss, closeTo(13.8155 * 3 / 4, 1e-3));
    });

    test('toJson carries every measure', () {
      final json = replay([
        for (var i = 0; i < 30; i++) _event(i, good: i.isEven),
      ], _Oracle()).toJson();
      expect(json, {
        'events': 10,
        'positives': 5,
        'auc': 1.0,
        'logLoss': closeTo(0.10536, 1e-4),
        'precisionAt10': 1.0,
        'baseRate': 0.5,
      });
    });
  });
}

class _AlwaysZero implements ReplayScorer {
  @override
  double predict(Title t) => 0;
  @override
  void learn(Title t, double label, double weight) {}
}
