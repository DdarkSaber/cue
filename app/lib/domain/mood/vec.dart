import 'dart:math' as math;

/// A sparse vector over mood features ("romance", "len:short", ...).
typedef Vec = Map<String, double>;

double _norm(Vec v) {
  var s = 0.0;
  for (final w in v.values) {
    s += w * w;
  }
  return math.sqrt(s);
}

/// Unit length, or empty when the vector is all zero.
Vec normalize(Vec v) {
  final n = _norm(v);
  if (n == 0) return {};
  return {for (final e in v.entries) e.key: e.value / n};
}

/// -1..1; 0 when either side is empty.
double cosine(Vec a, Vec b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final small = a.length <= b.length ? a : b;
  final large = identical(small, a) ? b : a;
  var dot = 0.0;
  for (final e in small.entries) {
    dot += e.value * (large[e.key] ?? 0);
  }
  final n = _norm(a) * _norm(b);
  return n == 0 ? 0 : dot / n;
}

/// Cosine where the set counts 1.0 for each feature.
double cosineSet(Set<String> features, Vec v) {
  if (features.isEmpty || v.isEmpty) return 0;
  var dot = 0.0;
  for (final f in features) {
    dot += v[f] ?? 0;
  }
  final n = math.sqrt(features.length) * _norm(v);
  return n == 0 ? 0 : dot / n;
}

/// a + k * b, as a new vector.
Vec addScaled(Vec a, Vec b, double k) {
  final out = Map<String, double>.of(a);
  for (final e in b.entries) {
    out[e.key] = (out[e.key] ?? 0) + k * e.value;
  }
  return out;
}

/// Keeps the [k] entries with the largest magnitude.
Vec topK(Vec v, int k) {
  if (v.length <= k) return Map.of(v);
  final entries = v.entries.toList()
    ..sort((x, y) => y.value.abs().compareTo(x.value.abs()));
  return {for (final e in entries.take(k)) e.key: e.value};
}
