import '../models/decision.dart';
import 'vec.dart';

/// How much a decision says about what the person wanted.
double signalFor(Decision d) => switch (d) {
  Decision.willTry => 1.0,
  Decision.watched => 0.8,
  Decision.notNow => -0.3,
  Decision.notInterested => -1.0,
};

/// One swipe as the mood learner needs it.
class MoodEvent {
  const MoodEvent({
    required this.id,
    required this.titleId,
    required this.decision,
    required this.at,
    this.reverses,
  });

  final String id;
  final String titleId;
  final Decision decision;
  final DateTime at;

  /// Set on undo events: the id of the event they cancel.
  final String? reverses;
}

class MoodSession {
  MoodSession(this.start);
  final DateTime start;
  late DateTime end = start;
  final picks = <(String titleId, double signal)>[];

  int get positives => picks.where((p) => p.$2 > 0).length;
  int get negatives => picks.where((p) => p.$2 < 0).length;

  /// Normalized sum of the features of positive picks, weighted by signal.
  Vec positiveVec(Set<String>? Function(String titleId) features) {
    var v = <String, double>{};
    for (final (id, s) in picks) {
      if (s <= 0) continue;
      final f = features(id);
      if (f == null) continue;
      v = addScaled(v, {for (final x in f) x: 1.0}, s);
    }
    return normalize(v);
  }
}

/// A new session starts after this much quiet.
const sessionGap = Duration(minutes: 45);

/// Groups swipes into sessions. Undone swipes and the undo events
/// themselves are dropped.
List<MoodSession> splitSessions(List<MoodEvent> events) {
  final undone = {for (final e in events) ?e.reverses};
  final kept = [
    for (final e in events)
      if (e.reverses == null && !undone.contains(e.id)) e,
  ]..sort((a, b) => a.at.compareTo(b.at));
  final out = <MoodSession>[];
  for (final e in kept) {
    if (out.isEmpty || e.at.difference(out.last.end) > sessionGap) {
      out.add(MoodSession(e.at));
    }
    out.last
      ..end = e.at
      ..picks.add((e.titleId, signalFor(e.decision)));
  }
  return out;
}

/// 0 morning (5-11), 1 afternoon (12-16), 2 evening (17-21), 3 late (22-4).
int hourBucket(DateTime t) {
  final h = t.hour;
  if (h >= 5 && h <= 11) return 0;
  if (h >= 12 && h <= 16) return 1;
  if (h >= 17 && h <= 21) return 2;
  return 3;
}
