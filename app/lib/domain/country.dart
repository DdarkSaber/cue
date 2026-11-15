/// Country of origin codes (AniList ISO 3166-1 alpha-2) as names people read.
const countryNames = {
  'JP': 'Japan',
  'KR': 'Korea',
  'CN': 'China',
  'TW': 'Taiwan',
  'HK': 'Hong Kong',
  'TH': 'Thailand',
  'US': 'United States',
  'GB': 'United Kingdom',
  'FR': 'France',
  'IN': 'India',
};

/// "KR" -> "Korea"; an unknown code is shown as it is.
String countryName(String code) => countryNames[code.toUpperCase()] ?? code;
