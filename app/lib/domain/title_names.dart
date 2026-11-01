/// Lower-case, punctuation-free form used for title comparison and search.
String normTitle(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[’‘`´]'), "'")
    .replaceAll("'", '')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();
