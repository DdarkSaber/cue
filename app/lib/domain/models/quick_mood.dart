/// Quick moods on the chip rail under the header (CUE-HANDOFF section 1).
enum QuickMood {
  forYou('For you'),
  hype('Hype'),
  comfort('Comfort'),
  gripping('Gripping'),
  feels('Feels'),
  revisit('Revisit');

  const QuickMood(this.label);
  final String label;
}
