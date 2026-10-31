import '../models/decision.dart';
import '../models/title.dart';
import '../ranker.dart' show RankedCard;
import 'mode_model.dart';
import 'mode_tracker.dart';
import 'mood_target.dart';
import 'mood_features.dart';
import 'sessions.dart';
import 'vec.dart';
import 'word_model.dart';

export 'mood_target.dart';

/// Storage the engine needs; [MoodRepository] in the app, a map in tests.
abstract class MoodStore {
  Future<(List<Mode>, WordModel)?> load(String profileId);
  Future<void> save(String profileId, List<Mode> modes, WordModel words);
  Future<List<MoodEvent>> events(String profileId);
  Future<void> sessionEnded(
    String profileId,
    MoodSession session, {
    String? typed,
    String? modeId,
  });
}

/// Ties the mood pieces together for one profile: learns modes from past
/// sessions, tracks the current one, and learns typed words.
class MoodEngine {
  MoodEngine(this.store, this.profileId, this.titlesByIds);

  final MoodStore store;
  final String profileId;
  final Future<List<Title>> Function(Iterable<String> ids) titlesByIds;

  ModeModel model = ModeModel();
  WordModel words = WordModel();
  ModeTracker? _tracker;
  MoodSession? _session;
  List<String> _tokens = const [];
  String _typed = '';
  final _features = <String, Set<String>>{};

  List<Mode> get modes => model.modes;

  Future<void> load() async {
    final saved = await store.load(profileId);
    if (saved != null) {
      model = ModeModel(saved.$1);
      words = saved.$2;
      return;
    }
    // First run: learn the modes from the swipe history there already is.
    final sessions = splitSessions(await store.events(profileId));
    final ids = {
      for (final s in sessions)
        for (final p in s.picks) p.$1,
    };
    for (final t in await titlesByIds(ids)) {
      _features[t.id] = moodFeatures(t);
    }
    model = ModeModel.discover(sessions, (id) => _features[id]);
    await store.save(profileId, model.modes, words);
  }

  /// Seeds modes from liked library titles when nothing was learned yet.
  Future<void> seedFrom(List<Title> liked) async {
    if (model.modes.isNotEmpty || liked.isEmpty) return;
    model = ModeModel.seed([for (final t in liked) moodFeatures(t)]);
    await store.save(profileId, model.modes, words);
  }

  void startSession({required DateTime now, String text = ''}) {
    _typed = text.trim();
    _tokens = tokenize(_typed);
    _session = MoodSession(now);
    _tracker = ModeTracker(
      model.modes,
      now: now,
      textVec: words.vectorFor(_tokens),
    );
  }

  bool get inSession => _session != null;
  DateTime? get lastActivity => _session?.end;

  void onSwipe(Title t, Decision d, {DateTime? at}) {
    final s = _session;
    if (s == null) return;
    final f = moodFeatures(t);
    _features[t.id] = f;
    s
      ..end = at ?? DateTime.now()
      ..picks.add((t.id, signalFor(d)));
    _tracker?.observe(f, signalFor(d));
  }

  void correct(String modeId) => _tracker?.force(modeId);

  MoodTarget get target {
    final t = _tracker;
    final textVec = words.vectorFor(_tokens);
    if (t == null || model.modes.isEmpty) {
      return textVec.isEmpty ? MoodTarget.none : MoodTarget(textVec, 0.5);
    }
    final vec = normalize(addScaled(t.mixture(), textVec, 0.5));
    final top = t.top;
    return MoodTarget(vec, t.confidence, label: top?.label, modeId: top?.id);
  }

  Mode? get secondMode => _tracker?.second;

  /// Learns from the finished session and saves.
  Future<void> endSession() async {
    final s = _session;
    if (s == null) return;
    final modeId = _tracker?.top?.id;
    _session = null;
    _tracker = null;
    if (s.picks.isEmpty) return;
    final vec = s.positiveVec((id) => _features[id]);
    model.absorb(vec, s.start, positives: s.positives);
    if (_tokens.isNotEmpty) words.learn(_tokens, vec);
    await store.save(profileId, model.modes, words);
    await store.sessionEnded(
      profileId,
      s,
      typed: _typed.isEmpty ? null : _typed,
      modeId: modeId,
    );
  }
}

/// Keeps some variety: every 5th card is the best one for the runner-up
/// mode, so a change of mood shows up quickly.
List<RankedCard> diversify(List<RankedCard> cards, Mode? second) {
  if (second == null || cards.length < 5) return cards;
  final rest = List.of(cards);
  final out = <RankedCard>[];
  while (rest.isNotEmpty) {
    if (out.length % 5 == 4 && rest.length > 1) {
      var best = 0;
      var bestSim = -2.0;
      for (var i = 0; i < rest.length; i++) {
        final s = cosine(
          featureVec(moodFeatures(rest[i].title)),
          second.centroid,
        );
        if (s > bestSim) {
          bestSim = s;
          best = i;
        }
      }
      out.add(rest.removeAt(best));
    } else {
      out.add(rest.removeAt(0));
    }
  }
  return out;
}
