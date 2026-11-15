import 'dart:math';

import '../models/title.dart';
import 'swipe_model.dart';

/// The swipe model plus what it needs to score a title: the pool's tag
/// rarity and which titles came from a liked title's "more like this" list.
/// Built on the device from the person's own decisions; never stored or sent.
class LearnedTaste {
  LearnedTaste(this.model, {this.idf = const {}, this.seeded = const {}});

  final SwipeModel model;
  final Map<String, double> idf;
  final Set<String> seeded;
  final _vectors = <String, Map<String, double>>{};

  /// How far the learned score may replace the hand-tuned one once the
  /// model has seen enough swipes.
  static const maxBlend = 0.6;

  double get blend => maxBlend * model.confidence;

  Map<String, double> vector(Title t) => _vectors.putIfAbsent(
    t.id,
    () => swipeFeatures(t, seeded: seeded.contains(t.id), idf: idf),
  );

  double _mean = 0;
  double _spread = 0;

  static double _logit(double p) {
    final q = p.clamp(1e-6, 1 - 1e-6);
    return log(q / (1 - q));
  }

  /// The model ranks well long before its probabilities spread out (after a
  /// few dozen swipes they still sit near 0.5). Scores are therefore read
  /// relative to the pool being dealt: call this once per deal.
  void calibrate(Iterable<Title> pool) {
    var n = 0;
    var sum = 0.0;
    var squares = 0.0;
    for (final t in pool) {
      final z = _logit(model.predict(vector(t)));
      n++;
      sum += z;
      squares += z * z;
    }
    if (n < 2) {
      _mean = 0;
      _spread = 0;
      return;
    }
    _mean = sum / n;
    final variance = squares / n - _mean * _mean;
    _spread = variance > 0 ? sqrt(variance) : 0;
  }

  /// 0..1: how likely this person is to save the title, relative to the
  /// calibrated pool (0.5 is an average candidate).
  double likes(Title t) {
    final p = model.predict(vector(t));
    if (_spread < 1e-9) return p;
    final z = (_logit(p) - _mean) / _spread;
    return 1 / (1 + exp(-1.2 * z));
  }

  /// Mixes the learned likelihood into a hand-tuned [score].
  double mix(Title t, double score) {
    final a = blend;
    return a == 0 ? score : (1 - a) * score + a * likes(t);
  }

  /// Worth for an exploration slot: an optimistic draw (titles the model
  /// knows little about can draw high) plus a nudge for plain unfamiliarity,
  /// so exploring goes where there is something to learn, not anywhere.
  double explore(Title t, Random random) {
    final x = vector(t);
    return 0.7 * model.sample(x, random) + 0.3 * model.uncertainty(x);
  }

  /// Teaches the model one outcome for [t].
  void learn(Title t, double label, double weight) {
    model.update(vector(t), label, weight: weight);
  }
}
