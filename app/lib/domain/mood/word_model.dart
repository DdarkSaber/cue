import 'vec.dart';

const _stop = {
  'a',
  'an',
  'the',
  'and',
  'or',
  'but',
  'i',
  'me',
  'my',
  'im',
  'want',
  'wanna',
  'something',
  'some',
  'to',
  'of',
  'in',
  'on',
  'for',
  'with',
  'is',
  'it',
  'be',
  'that',
  'this',
  'just',
  'like',
  'today',
  'now',
  'feel',
};

/// Lower-cased words and two-word phrases. No meanings are built in.
List<String> tokenize(String text) {
  final words = [
    for (final w in text.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
      if (w.length >= 2 && !_stop.contains(w)) w,
  ];
  return [
    ...words,
    for (var i = 0; i + 1 < words.length; i++) '${words[i]} ${words[i + 1]}',
  ];
}

class WordEntry {
  WordEntry(this.weights, this.uses);
  Vec weights;
  int uses;
}

/// What each typed word has meant for this person: the features of what
/// they picked after typing it. A word counts only after [minUses].
class WordModel {
  WordModel([Map<String, WordEntry>? words]) : words = words ?? {};

  static const lr = 0.3;
  static const keep = 60;
  static const minUses = 2;

  final Map<String, WordEntry> words;

  /// Called at the end of a session in which these words were typed.
  void learn(List<String> tokens, Vec sessionPositiveVec) {
    if (sessionPositiveVec.isEmpty) return;
    for (final t in tokens.toSet()) {
      final e = words[t];
      if (e == null) {
        words[t] = WordEntry(topK(normalize(sessionPositiveVec), keep), 1);
      } else {
        e
          ..weights = normalize(
            topK(addScaled(e.weights, sessionPositiveVec, lr), keep),
          )
          ..uses += 1;
      }
    }
  }

  Vec vectorFor(List<String> tokens) {
    var v = <String, double>{};
    for (final t in tokens) {
      final e = words[t];
      if (e == null || e.uses < minUses) continue;
      v = addScaled(v, e.weights, 1);
    }
    return normalize(v);
  }
}
