import 'models/quick_mood.dart';

/// Mood tag sets. Catalog genres and tags are matched lower-cased.
/// Fixed for everyone; personal taste comes from tag weights instead.
const moodTags = <QuickMood, Set<String>>{
  QuickMood.hype: {
    'sports',
    'shounen',
    'action',
    'tournament',
    'underdog',
    'super power',
    'action & adventure',
    'adventure',
    'martial arts',
    'battle royale',
  },
  QuickMood.comfort: {
    'slice of life',
    'comedy',
    'iyashikei',
    'found family',
    'episodic',
    'workplace comedy',
    'family',
    'cute girls doing cute things',
    'food',
    'healing',
  },
  QuickMood.gripping: {
    'thriller',
    'mystery',
    'crime',
    'psychological',
    'legal',
    'medical',
    'revenge',
    'suspense',
    'detective',
    'conspiracy',
  },
  QuickMood.feels: {
    'romance',
    'drama',
    'coming of age',
    'tragedy',
    'romantic comedy',
    'love triangle',
    'melancholy',
    'heartwarming',
  },
};

/// Share of a mood's vocabulary a title touches, scaled so two hits ~ 1.
double moodOverlap(Set<String> features, QuickMood mood) {
  final tags = moodTags[mood];
  if (tags == null) return 0.5;
  final hits = features.where(tags.contains).length;
  return (hits / 2).clamp(0, 1).toDouble();
}
