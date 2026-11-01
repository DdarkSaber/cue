import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    CatalogTitles,
    CatalogIdentities,
    CatalogPages,
    WatchProviders,
    Profiles,
    ProfileSettings,
    UserTitles,
    DecisionEvents,
    Shortlist,
    Deferrals,
    Exclusions,
    TagWeights,
    ImportBatches,
    SourceObservations,
    ImportChanges,
    MoodStates,
    MoodSessions,
    RecommendationStates,
  ],
)
class CueDatabase extends _$CueDatabase {
  CueDatabase(super.e);

  /// The on-device database. Web uses Drift's WASM build (files in web/).
  factory CueDatabase.open() => CueDatabase(
    driftDatabase(
      name: 'cue',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_events_profile_time '
        'ON decision_events (profile_id, created_at)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_identity_title '
        'ON catalog_identities (title_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_catalog_kind '
        'ON catalog_titles (media_kind)',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(moodStates);
        await m.createTable(moodSessions);
      }
      if (from < 3) {
        await m.addColumn(sourceObservations, sourceObservations.candidateJson);
      }
      if (from < 4) await m.createTable(recommendationStates);
      if (from < 5) {
        await m.addColumn(sourceObservations, sourceObservations.recordJson);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
