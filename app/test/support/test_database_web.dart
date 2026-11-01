import 'package:cue/data/db/database.dart';
import 'package:drift/wasm.dart';
import 'package:drift_flutter/drift_flutter.dart';

int _sequence = 0;
final _syntheticNames = <String>{};
Future<void> Function()? beforeSyntheticDatabaseClose;

String syntheticDatabaseName() {
  final name =
      'cue_synthetic_test_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}';
  _syntheticNames.add(name);
  return name;
}

CueDatabase openTestDatabase({String? name}) {
  name ??= syntheticDatabaseName();
  if (!_syntheticNames.contains(name)) {
    throw ArgumentError('Only databases issued by this test helper may open.');
  }
  return _SyntheticBrowserDatabase(
    driftDatabase(
      name: name,
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
        onResult: (result) {
          if (result.chosenImplementation.storageApi == null) {
            throw StateError(
              'Browser tests require persistent SQLite storage.',
            );
          }
        },
      ),
    ),
  );
}

class _SyntheticBrowserDatabase extends CueDatabase {
  _SyntheticBrowserDatabase(super.connection);

  @override
  Future<void> close() async {
    await beforeSyntheticDatabaseClose?.call();
    await super.close();
  }
}

/// Call only after all test database connections have closed.
Future<void> deleteSyntheticDatabase(String name) async {
  if (!_syntheticNames.contains(name)) {
    throw ArgumentError(
      'Refusing to delete a database not issued by this test.',
    );
  }
  final probe = await WasmDatabase.probe(
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
    databaseName: name,
  );
  for (final database in probe.existingDatabases) {
    if (database.$2 == name) await probe.deleteDatabase(database);
  }
  final after = await WasmDatabase.probe(
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
    databaseName: name,
  );
  if (after.existingDatabases.any((database) => database.$2 == name)) {
    throw StateError('Synthetic browser database cleanup did not complete.');
  }
}

Future<void> deleteAllSyntheticDatabases() async {
  for (final name in _syntheticNames.toList()) {
    await deleteSyntheticDatabase(name);
  }
  _syntheticNames.clear();
}
