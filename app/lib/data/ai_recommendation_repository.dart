import 'dart:convert';

import '../domain/ai_taste.dart';
import '../domain/models/title.dart';
import '../domain/ranker.dart';
import '../imports/matcher.dart';
import '../imports/records.dart';
import 'ai_recommendation_client.dart';
import 'catalog_repository.dart';
import 'profile_repository.dart';

/// Builds a compact taste profile, asks the opt-in AI route for suggestions,
/// then keeps only those found in the real catalog. Resolved titles land in
/// the normal catalog cache; the provenance (`because`, `why`) is kept per
/// profile in settings, so no catalog schema change is needed.
class AiRecommendationRepository {
  AiRecommendationRepository({
    required this.client,
    required this.catalog,
    required this.profiles,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final AiRecommendationClient client;
  final CatalogRepository catalog;
  final ProfileRepository profiles;
  final DateTime Function() _now;

  static const _key = 'aiPicks.v1';

  /// Bumped whenever picks are forgotten, so a refresh that was already in
  /// flight when the toggle went off cannot store its answer afterwards.
  static int _forgotten = 0;

  /// Deletes the stored picks of [profileId] (the toggle went off).
  static Future<void> forget(ProfileRepository profiles, String profileId) {
    _forgotten++;
    return profiles.setRawSetting(profileId, _key, null);
  }

  static const minPositive = 5;

  /// Most suggestions looked up per refresh. Lookups are batched through the
  /// same paced AniList client as discovery (12 per request).
  static const maxLookups = 30;
  static const refreshAfter = Duration(hours: 4);
  static const refreshAfterNewRatings = 5;

  Future<({DateTime? at, int evidence, Map<String, AiPick> picks})> _load(
    String profileId,
  ) async {
    final raw = await profiles.rawSetting(profileId, _key);
    if (raw == null) return (at: null, evidence: 0, picks: <String, AiPick>{});
    try {
      final j = jsonDecode(raw) as Map;
      return (
        at: DateTime.tryParse('${j['at']}'),
        evidence: (j['evidence'] as num?)?.toInt() ?? 0,
        picks: <String, AiPick>{
          for (final p in [
            for (final x in (j['picks'] as List? ?? const []))
              ?AiPick.fromJson(x),
          ])
            p.titleId: p,
        },
      );
    } on Object {
      return (at: null, evidence: 0, picks: <String, AiPick>{});
    }
  }

  /// Provenance of the stored picks for this profile, by title id.
  Future<Map<String, AiPick>> picks(String profileId) async =>
      (await _load(profileId)).picks;

  Future<void> clear(String profileId) => forget(profiles, profileId);

  static int ratedCount(ProfileSignals s) =>
      s.library.values.where((e) => e.rating != null).length;

  /// True when the person has enough positive titles for the feature to help.
  static bool hasEnoughTaste(ProfileSignals s, Map<String, Title> titles) =>
      positiveEvidence(s, titles).length >= minPositive;

  /// Refreshes when the stored picks are old, or enough new ratings arrived.
  /// Returns true when new picks were stored. Failures keep the old picks.
  Future<bool> refreshIfDue(
    String profileId,
    ProfileSignals signals,
    Set<MediaKind> enabledKinds, {
    bool force = false,
  }) async {
    final generation = _forgotten;
    final stored = await _load(profileId);
    final rated = ratedCount(signals);
    final due =
        force ||
        stored.at == null ||
        _now().difference(stored.at!) >= refreshAfter ||
        rated - stored.evidence >= refreshAfterNewRatings;
    if (!due) return false;

    final ids = {
      ...signals.library.keys,
      ...signals.shortlisted,
      ...negativeIds(signals),
    };
    final titles = {for (final t in await catalog.titlesByIds(ids)) t.id: t};
    final evidence = positiveEvidence(signals, titles);
    if (evidence.length < minPositive) return false;
    final kinds = enabledKinds.where((k) => k != MediaKind.unknown).toSet();
    if (kinds.isEmpty) return false;

    final negatives = [
      for (final id in negativeIds(signals))
        if (titles[id] case final t? when t.kind != MediaKind.unknown) t,
    ].take(10).toList();
    final profile = AiTasteProfile(
      liked: [
        for (final e in evidence)
          AiTasteItem(
            _name(e.title),
            e.title.kind,
            year: e.title.year,
            rating: ratingOutOf10(e.rating),
          ),
      ],
      disliked: [for (final t in negatives) AiTasteItem(_name(t), t.kind)],
      kinds: kinds,
    );

    final List<AiSuggestion> suggestions;
    try {
      suggestions = await client.recommend(profile);
    } on AiRecommendationUnavailable {
      return false;
    }
    final resolved = await _resolve(suggestions, signals, titles, kinds);
    if (resolved.isEmpty || generation != _forgotten) return false;
    await profiles.setRawSetting(
      profileId,
      _key,
      jsonEncode({
        'at': _now().toIso8601String(),
        'evidence': rated,
        'picks': [for (final p in resolved) p.toJson()],
      }),
    );
    return true;
  }

  static String _name(Title t) {
    final n = t.titleEn ?? t.titleRomaji ?? t.titleNative ?? t.displayTitle;
    return n.length > 100 ? n.substring(0, 100) : n;
  }

  /// Resolves names with the import matcher. Anything not found with an exact
  /// title, ambiguous, adult, novel or music, already in the library, or
  /// rejected is dropped. Nothing is ever invented.
  Future<List<AiPick>> _resolve(
    List<AiSuggestion> suggestions,
    ProfileSignals signals,
    Map<String, Title> known,
    Set<MediaKind> kinds,
  ) async {
    final matcher = ImportMatcher(catalog);
    final blocked = {
      ...signals.library.keys,
      ...signals.shortlisted,
      ...signals.deferred,
      ...negativeIds(signals),
    };
    final blockedFranchises = {
      ...signals.excludedFranchises,
      for (final id in blocked)
        if (known[id] case final t?) t.franchiseKey,
    };
    final out = <AiPick>[];
    final seen = <String>{};
    final wanted = suggestions.take(maxLookups).toList();
    for (var i = 0; i < wanted.length; i += ImportMatcher.batchSize) {
      final chunk = wanted.skip(i).take(ImportMatcher.batchSize).toList();
      final List<MatchedRecord> matched;
      try {
        matched = await matcher.match([
          for (var k = 0; k < chunk.length; k++)
            NormalizedRecord(
              sourceEntryKey: 'ai:${i + k}',
              title: chunk[k].title,
              kind: chunk[k].kind,
              year: chunk[k].year,
            ),
        ]);
      } on Exception {
        break;
      }
      for (var k = 0; k < chunk.length; k++) {
        final m = matched[k];
        final id = m.titleId;
        if (id == null ||
            m.matchClass == MatchClass.similar ||
            m.matchClass == MatchClass.unresolved ||
            m.adultHidden ||
            blocked.contains(id) ||
            !seen.add(id)) {
          continue;
        }
        final t = await catalog.titleById(id);
        if (t == null ||
            t.adult ||
            t.format == 'NOVEL' ||
            t.format == 'MUSIC' ||
            !kinds.contains(t.kind) ||
            blockedFranchises.contains(t.franchiseKey)) {
          continue;
        }
        out.add(AiPick(id, chunk[k].because, chunk[k].why));
      }
    }
    return out;
  }
}
