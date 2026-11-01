/// Human names for import sources, shown in Library and Past imports.
String importSourceName(String type) => switch (type) {
  'mal_xml' => 'MyAnimeList file',
  'netflix_csv' => 'Netflix activity',
  'cue_backup' => 'Cue backup',
  'xlsx' => 'Spreadsheet',
  'generic_csv' => 'CSV file',
  'mihon_backup' => 'Mihon backup',
  'mal_api' => 'MyAnimeList sign-in',
  'anilist_api' => 'AniList list',
  'sync' => 'sync',
  _ => 'Import',
};
