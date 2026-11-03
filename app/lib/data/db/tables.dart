import 'package:drift/drift.dart';

// ---------------------------------------------------------------------------
// Catalog: shared public metadata. Never personal.
// ---------------------------------------------------------------------------

/// Title ids are stable strings built from the provider identity
/// ("anilist:101", "tmdb:tv:9", "tvmaze:3"), so a backup or a second device
/// resolves the same title to the same row.
class CatalogTitles extends Table {
  TextColumn get id => text()();
  TextColumn get mediaKind => text()();
  TextColumn get titleEn => text().nullable()();
  TextColumn get titleRomaji => text().nullable()();
  TextColumn get titleNative => text().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get format => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('unknown'))();
  IntColumn get episodes => integer().nullable()();
  IntColumn get chapters => integer().nullable()();
  TextColumn get seasonsJson => text().withDefault(const Constant('[]'))();
  TextColumn get genresJson => text().withDefault(const Constant('[]'))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  IntColumn get score => integer().nullable()();
  TextColumn get posterUrl => text().nullable()();
  TextColumn get backdropUrl => text().nullable()();
  TextColumn get synopsis => text().nullable()();
  TextColumn get franchiseId => text().nullable()();
  BoolColumn get adult => boolean().withDefault(const Constant(false))();

  /// True once the full title (seasons, keywords) has been fetched.
  BoolColumn get detailed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CatalogIdentity')
class CatalogIdentities extends Table {
  TextColumn get titleId => text().references(CatalogTitles, #id)();
  TextColumn get provider => text()();
  TextColumn get providerId => text()();
  TextColumn get providerKind => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {provider, providerId, providerKind};
}

/// Which discover pages have been pulled, so the pool grows without refetching.
class CatalogPages extends Table {
  TextColumn get mediaKind => text()();
  TextColumn get mood => text().withDefault(const Constant(''))();
  IntColumn get page => integer()();
  BoolColumn get hasNext => boolean()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {mediaKind, mood, page};
}

/// Public "more like this" edges: the provider (AniList community, TMDB)
/// recommends [titleId] to people who liked [seedId]. Both are catalog ids.
/// Nothing here says who liked what; the deck joins these edges with the
/// active profile's liked titles in memory.
class CatalogRecommendations extends Table {
  TextColumn get seedId => text()();
  TextColumn get titleId => text()();

  /// Position in the provider's list, 0 = best rated.
  IntColumn get rank => integer()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {seedId, titleId};
}

class WatchProviders extends Table {
  TextColumn get titleId => text().references(CatalogTitles, #id)();
  TextColumn get region => text()();
  TextColumn get providersJson => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {titleId, region};
}

// ---------------------------------------------------------------------------
// Personal: every row carries profileId.
// ---------------------------------------------------------------------------

class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get region => text().withDefault(const Constant('IN'))();
  BoolColumn get showAdult => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Profile preferences as key/value text (motion, swipe map, AI, sync...).
class ProfileSettings extends Table {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {profileId, key};
}

/// Device-only recommendation measures, exposure caps and dismissed prompts.
/// Deliberately absent from backups and encrypted sync.
class RecommendationStates extends Table {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get json => text()();
  @override
  Set<Column> get primaryKey => {profileId};
}

class UserTitles extends Table {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get titleId => text()();
  TextColumn get state => text().withDefault(const Constant('none'))();
  TextColumn get rating => text().nullable()();
  TextColumn get rewatchMood => text().nullable()();
  TextColumn get progressUnit => text().nullable()();
  RealColumn get progressValue => real().nullable()();
  RealColumn get latestKnown => real().nullable()();
  DateTimeColumn get actualWatchedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  /// "user" or "import:`batchId`".
  TextColumn get source => text().withDefault(const Constant('user'))();

  /// Free text from a Cue backup; never shown to the ranker.
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {profileId, titleId};
}

class DecisionEvents extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get titleId => text()();
  TextColumn get action => text()();
  TextColumn get context => text().withDefault(const Constant('deck'))();
  TextColumn get mood => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get reversesEventId => text().nullable()();

  /// Rows this event replaced, so undo works after a restart.
  TextColumn get beforeJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ShortlistEntry')
class Shortlist extends Table {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get titleId => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId, titleId};
}

class Deferrals extends Table {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get titleId => text()();
  DateTimeColumn get eligibleAfter => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId, titleId};
}

class Exclusions extends Table {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get titleId => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId, titleId};
}

class TagWeights extends Table {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get tag => text()();
  RealColumn get weight => real()();
  IntColumn get evidenceCount => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId, tag};
}

// ---------------------------------------------------------------------------
// Mood learning (local only; see design/mood)
// ---------------------------------------------------------------------------

/// The learned modes and word meanings for a profile, as JSON.
@DataClassName('MoodState')
class MoodStates extends Table {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get modesJson => text().withDefault(const Constant('[]'))();
  TextColumn get wordsJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId};
}

/// One finished deck session, for review and for rebuilding the modes.
@DataClassName('MoodSessionRow')
class MoodSessions extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  TextColumn get typed => text().nullable()();
  TextColumn get modeId => text().nullable()();
  IntColumn get positives => integer()();
  IntColumn get negatives => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Imports
// ---------------------------------------------------------------------------

@DataClassName('ImportBatch')
class ImportBatches extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get sourceType => text()();
  TextColumn get adapterVersion => text()();
  TextColumn get fileFingerprint => text().nullable()();
  TextColumn get state => text()();
  TextColumn get countsJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SourceObservation')
class SourceObservations extends Table {
  TextColumn get id => text()();
  TextColumn get batchId => text().references(ImportBatches, #id)();
  TextColumn get sourceEntryKey => text()();
  TextColumn get rawTitle => text()();
  TextColumn get titleId => text().nullable()();
  TextColumn get matchClass => text()();
  TextColumn get status => text()();
  TextColumn get ratingOriginal => text().nullable()();
  TextColumn get ratingScale => text().nullable()();
  RealColumn get progress => real().nullable()();
  DateTimeColumn get activityDate => dateTime().nullable()();
  BoolColumn get included => boolean().withDefault(const Constant(true))();

  /// The similar title offered but not ticked (catalog JSON), so the review
  /// queue can accept it later in one go.
  TextColumn get candidateJson => text().nullable()();

  /// Local-only original fields needed when an unresolved row is reviewed.
  TextColumn get recordJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ImportChange')
class ImportChanges extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get batchId => text().references(ImportBatches, #id)();
  TextColumn get tableName_ => text().named('table_name')();
  TextColumn get rowKey => text()();
  TextColumn get beforeJson => text().nullable()();
  TextColumn get afterJson => text().nullable()();
}
