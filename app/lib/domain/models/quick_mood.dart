/// Quick moods on the chip rail under the header.
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
