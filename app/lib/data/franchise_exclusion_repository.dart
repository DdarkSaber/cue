import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/franchise_identity.dart';
import '../domain/models/title.dart';
import 'db/database.dart';

class FranchiseExclusionRecord {
  const FranchiseExclusionRecord({
    required this.scope,
    required this.excluded,
    required this.updatedAt,
  });

  final String scope;
  final bool excluded;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'scope': scope,
    'excluded': excluded,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static FranchiseExclusionRecord? fromJson(Map<String, dynamic> json) {
    final scope = json['scope'];
    final excluded = json['excluded'];
    final rawTime = json['updatedAt'];
    if (scope is! String ||
        !isReliableFranchiseScope(scope) ||
        excluded is! bool ||
        rawTime is! String ||
        !rawTime.endsWith('Z')) {
      return null;
    }
    final time = DateTime.tryParse(rawTime);
    if (time == null) return null;
    return FranchiseExclusionRecord(
      scope: scope,
      excluded: excluded,
      updatedAt: time.toUtc(),
    );
  }
}

class FranchiseExclusionChange {
  const FranchiseExclusionChange._(
    this.profileId,
    this.scope,
    this.previouslyExcluded,
    this.afterValue,
  );

  final String profileId;
  final String scope;
  final bool previouslyExcluded;
  final String afterValue;
}

/// Persistent per-library preferences, including restoration tombstones.
/// Backup/sync merge these records by timestamp; tied restoration wins.
class FranchiseExclusionRepository {
  FranchiseExclusionRepository(this.db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  static const metadataPrefix = '_franchise_exclusion_v1:';
  final CueDatabase db;
  final DateTime Function() _now;

  Future<Set<String>> activeScopes(String profileId) async {
    final rows = await (db.select(
      db.profileSettings,
    )..where((s) => s.profileId.equals(profileId))).get();
    return {
      for (final row in rows)
        if (row.key.startsWith(metadataPrefix))
          if (_decode(row.value) case final record?)
            if (record.excluded && row.key == '$metadataPrefix${record.scope}')
              record.scope,
    };
  }

  Future<FranchiseExclusionChange> exclude(String profileId, Title title) {
    final scope = reliableFranchiseId(title);
    if (scope == null) {
      throw ArgumentError('This title has no verified provider collection.');
    }
    return _change(profileId, scope, true);
  }

  Future<FranchiseExclusionChange> restore(String profileId, String scope) =>
      _change(profileId, scope, false);

  Future<FranchiseExclusionChange> _change(
    String profileId,
    String scope,
    bool excluded,
  ) {
    if (!isReliableFranchiseScope(scope)) {
      throw ArgumentError.value(scope, 'scope', 'Unverified collection');
    }
    return db.transaction(() async {
      final previous = await _value(profileId, scope);
      return _write(profileId, scope, excluded, previous);
    });
  }

  /// Refuses to overwrite any newer local or synchronized preference.
  Future<bool> undo(FranchiseExclusionChange change) =>
      db.transaction(() async {
        final current = await _value(change.profileId, change.scope);
        if (current != change.afterValue) return false;
        await _write(
          change.profileId,
          change.scope,
          change.previouslyExcluded,
          current,
        );
        return true;
      });

  Future<String?> _value(String profileId, String scope) async =>
      (await (db.select(db.profileSettings)..where(
                (s) =>
                    s.profileId.equals(profileId) &
                    s.key.equals('$metadataPrefix$scope'),
              ))
              .getSingleOrNull())
          ?.value;

  Future<FranchiseExclusionChange> _write(
    String profileId,
    String scope,
    bool excluded,
    String? previousValue,
  ) async {
    final decoded = _decode(previousValue);
    final previous = decoded?.scope == scope ? decoded : null;
    var millis = _now().millisecondsSinceEpoch;
    if (previous != null &&
        millis <= previous.updatedAt.millisecondsSinceEpoch) {
      millis = previous.updatedAt.millisecondsSinceEpoch + 1;
    }
    final value = jsonEncode(
      FranchiseExclusionRecord(
        scope: scope,
        excluded: excluded,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
      ).toJson(),
    );
    await db
        .into(db.profileSettings)
        .insertOnConflictUpdate(
          ProfileSettingsCompanion.insert(
            profileId: profileId,
            key: '$metadataPrefix$scope',
            value: value,
          ),
        );
    return FranchiseExclusionChange._(
      profileId,
      scope,
      previous?.excluded ?? false,
      value,
    );
  }

  static FranchiseExclusionRecord? _decode(String? value) {
    if (value == null) return null;
    try {
      final json = jsonDecode(value);
      return json is Map<String, dynamic>
          ? FranchiseExclusionRecord.fromJson(json)
          : null;
    } on FormatException {
      return null;
    }
  }
}
