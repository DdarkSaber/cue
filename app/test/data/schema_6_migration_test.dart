import 'dart:io';

import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test(
    'upgrading from schema 5 adds catalog_recommendations and keeps data',
    () async {
      final dir = await Directory.systemTemp.createTemp('cue-schema6-');
      final file = File('${dir.path}${Platform.pathSeparator}cue.sqlite');
      var db = CueDatabase(NativeDatabase(file));
      try {
        final ids = await CatalogRepository(
          db,
          FakeGateway(),
        ).upsert([CatalogItemDto(item(1)), CatalogItemDto(item(2))]);
        await db.customStatement('DROP TABLE catalog_recommendations');
        await db.customStatement('PRAGMA user_version = 5');
        await db.close();

        db = CueDatabase(NativeDatabase(file));
        expect(await db.select(db.catalogTitles).get(), hasLength(2));
        await db
            .into(db.catalogRecommendations)
            .insert(
              CatalogRecommendationsCompanion.insert(
                seedId: ids[0],
                titleId: ids[1],
                rank: 0,
                fetchedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        expect(await db.select(db.catalogRecommendations).get(), hasLength(1));
        final version = await db
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), greaterThanOrEqualTo(6));
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
