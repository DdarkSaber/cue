import 'models/library.dart';
import 'models/title.dart';
import 'ranker.dart';

/// Provenance of a deck candidate that an opt-in source suggested. Mirrors
/// the "because you liked" seed idea: [because] is a title from the library,
/// [why] a short model-written reason. Never shown unless the title was found
/// in the real catalog.
class AiPick {
  const AiPick(this.titleId, this.because, this.why);
  final String titleId;
  final String because;
  final String why;

  Map<String, String> toJson() => {
    'id': titleId,
    'because': because,
    'why': why,
  };

  static AiPick? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], b = j['because'], w = j['why'];
    return id is String && b is String && w is String ? AiPick(id, b, w) : null;
  }

  /// "Because you loved X: why", kept to one readable line.
  String get reason {
    const max = 110;
    final lead = 'Because you loved $because: ';
    final room = max - lead.length;
    if (room < 12) return 'Because you loved $because.';
    final text = why.length <= room
        ? why
        : '${why.substring(0, room - 1).trimRight()}…';
    return '$lead$text';
  }
}

/// Evidence for the profile: who and why, in the order it is trusted.
class AiEvidence {
  const AiEvidence(this.title, this.rating, this.tier);
  final Title title;
  final Rating? rating;

  /// 0 explicit high rating, 1 saved/shortlisted, 2 imported completed.
  final int tier;
}

/// Positive evidence in trust order, at most [limit], one per franchise.
/// Explicit high ratings first, then saved titles, then completed imports.
List<AiEvidence> positiveEvidence(
  ProfileSignals s,
  Map<String, Title> titles, {
  int limit = 25,
}) {
  final out = <AiEvidence>[];
  final seen = <String>{};
  void add(String id, Rating? r, int tier) {
    final t = titles[id];
    if (t == null || t.adult || t.kind == MediaKind.unknown) return;
    if (t.format == 'NOVEL' || t.format == 'MUSIC') return;
    if (!seen.add(t.franchiseKey)) return;
    out.add(AiEvidence(t, r, tier));
  }

  final rated =
      s.library.values.where((e) => (e.rating?.weight ?? 0) >= 2).toList()
        ..sort((a, b) => b.rating!.weight.compareTo(a.rating!.weight));
  for (final e in rated) {
    add(e.titleId, e.rating, 0);
  }
  for (final id in s.shortlisted) {
    add(id, null, 1);
  }
  for (final e in s.library.values) {
    if (e.rating == null && e.state == LibraryState.completed) {
      add(e.titleId, null, 2);
    }
  }
  return out.take(limit).toList();
}

/// Ids of titles the person rejected: disliked or dropped, or marked not
/// interested. Used for the profile's negatives and to filter suggestions.
Set<String> negativeIds(ProfileSignals s) => {
  for (final e in s.library.values)
    if ((e.rating?.weight ?? 0) < 0 || e.state == LibraryState.dropped)
      e.titleId,
  ...s.excluded,
};

/// 0-10 for explicit ratings only.
int? ratingOutOf10(Rating? r) => switch (r) {
  Rating.favourite || Rating.rewatched => 10,
  Rating.wouldRewatch => 9,
  Rating.enjoyed => 8,
  _ => null,
};

/// Interleaves AI-resolved cards into the normal deal. Cards from [ai] get a
/// bounded score boost, but never take more than [maxShare] of the slots.
/// Both inputs are already hard-filtered by the ranker.
List<RankedCard> mixAiCards(
  List<RankedCard> main,
  List<RankedCard> ai,
  Map<String, AiPick> picks, {
  required int size,
  double boost = 0.06,
  double maxShare = 0.3,
}) {
  final cap = (size * maxShare).floor();
  final aiCards = [
    for (final c in ai.take(cap))
      RankedCard(
        c.title,
        c.score + boost,
        // The pick's own reason replaces any "Because you liked <seed>"
        // line: a card shows exactly one reason.
        picks[c.title.id]?.reason ?? c.reason,
        becauseOf: c.becauseOf,
      ),
  ];
  final out = <RankedCard>[];
  var i = 0, j = 0;
  while (out.length < size && (i < main.length || j < aiCards.length)) {
    final takeAi =
        j < aiCards.length &&
        (i >= main.length || aiCards[j].score > main[i].score);
    out.add(takeAi ? aiCards[j++] : main[i++]);
  }
  return out;
}
