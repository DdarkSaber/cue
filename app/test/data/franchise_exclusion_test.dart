import 'dart:convert';

import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/franchise_exclusion_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/franchise_identity.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

const collectionTitle = Title(
  id: 'tmdb:movie:123',
  kind: MediaKind.movie,
  titleEn: 'Synthetic collection member',
  franchiseId: 'tmdb:c456',
);

void main() {
  test(
    'catalog DTO preserves explicit provider collection, never title fallback',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final catalog = CatalogRepository(db, FakeGateway());
      final ids = await catalog.upsert([
        CatalogItemDto(
          item(
            123,
            provider: 'tmdb',
            providerKind: 'movie',
            kind: 'movie',
            franchiseKey: 'tmdb:c456',
          ),
        ),
        CatalogItemDto(
          item(
            124,
            provider: 'tmdb',
            providerKind: 'movie',
            kind: 'movie',
            title: 'Synthetic Part 2',
          ),
        ),
      ], detailed: true);
      final known = (await catalog.titleById(ids.first))!;
      final unknown = (await catalog.titleById(ids.last))!;
      expect(known.franchiseId, 'tmdb:c456');
      expect(reliableFranchiseId(known), 'tmdb:c456');
      expect(unknown.franchiseId, isNull);
      expect(unknown.franchiseKey, startsWith('w:'));
      expect(reliableFranchiseId(unknown), isNull);
    },
  );

  test('only explicit matching TMDB movie collection identity is reliable', () {
    expect(reliableFranchiseId(collectionTitle), 'tmdb:c456');
    for (final title in [
      const Title(
        id: 'tmdb:movie:123',
        kind: MediaKind.movie,
        titleEn: 'Synthetic collection member Part 2',
      ),
      const Title(
        id: 'tmdb:movie:123',
        kind: MediaKind.movie,
        franchiseId: 'w:synthetic collection member',
      ),
      const Title(
        id: 'anilist:123',
        kind: MediaKind.anime,
        franchiseId: 'anilist:100',
      ),
      const Title(
        id: 'local:123',
        kind: MediaKind.movie,
        franchiseId: 'tmdb:c456',
      ),
      const Title(
        id: 'tmdb:tv:123',
        kind: MediaKind.series,
        franchiseId: 'tmdb:c456',
      ),
      const Title(
        id: 'tmdb:movie:123',
        kind: MediaKind.movie,
        franchiseId: 'tmdb:c0',
      ),
      const Title(
        id: 'tmdb:movie:123',
        kind: MediaKind.movie,
        franchiseId: 'tmdb:cguess',
      ),
    ]) {
      expect(reliableFranchiseId(title), isNull, reason: title.id);
    }
  });

  test(
    'persistent profile isolation, restoration tombstones and guarded Undo',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final profiles = ProfileRepository(db);
      final a = (await profiles.ensureActive()).id;
      final b = (await profiles.create()).id;
      final now = DateTime.utc(2026, 1, 1);
      final repo = FranchiseExclusionRepository(db, clock: () => now);
      final change = await repo.exclude(a, collectionTitle);
      expect(await repo.activeScopes(a), {'tmdb:c456'});
      expect(await repo.activeScopes(b), isEmpty);
      expect(await FranchiseExclusionRepository(db).activeScopes(a), {
        'tmdb:c456',
      });
      expect(await repo.undo(change), isTrue);
      expect(await repo.activeScopes(a), isEmpty);
      expect(await repo.undo(change), isFalse);
      const key = '${FranchiseExclusionRepository.metadataPrefix}tmdb:c456';
      final tombstone = jsonDecode(
        (await profiles.rawSetting(a, key))!,
      ) as Map<String, dynamic>;
      expect(tombstone['excluded'], isFalse);
      expect(
        DateTime.parse(tombstone['updatedAt'] as String).isAfter(now),
        isTrue,
      );
      await repo.exclude(a, collectionTitle);
      final restored = await repo.restore(a, 'tmdb:c456');
      expect(await repo.activeScopes(a), isEmpty);
      expect(await repo.undo(restored), isTrue);
      expect(await repo.activeScopes(a), {'tmdb:c456'});
      await repo.exclude(b, collectionTitle);
      await profiles.deleteProfile(a);
      expect(await repo.activeScopes(a), isEmpty);
      expect(await repo.activeScopes(b), {'tmdb:c456'});
    },
  );

  test(
    'newer synchronized writes survive stale undo and clock rollback',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final profiles = ProfileRepository(db);
      final profileId = (await profiles.ensureActive()).id;
      final now = DateTime.utc(2026, 1, 1);
      final repo = FranchiseExclusionRepository(db, clock: () => now);
      final change = await repo.exclude(profileId, collectionTitle);
      final future = now.add(const Duration(days: 3));
      const key = '${FranchiseExclusionRepository.metadataPrefix}tmdb:c456';
      await profiles.setRawSetting(
        profileId,
        key,
        jsonEncode(
          FranchiseExclusionRecord(
            scope: 'tmdb:c456',
            excluded: false,
            updatedAt: future,
          ).toJson(),
        ),
      );
      expect(await repo.undo(change), isFalse);
      expect(await repo.activeScopes(profileId), isEmpty);
      final next = await repo.exclude(profileId, collectionTitle);
      final parsed = FranchiseExclusionRecord.fromJson(
        jsonDecode(next.afterValue) as Map<String, dynamic>,
      )!;
      expect(parsed.updatedAt.isAfter(future), isTrue);
    },
  );

  test('unknown/malformed metadata never grants exclusions', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final profiles = ProfileRepository(db);
    final profileId = (await profiles.ensureActive()).id;
    const prefix = FranchiseExclusionRepository.metadataPrefix;
    await profiles.setRawSetting(profileId, '${prefix}tmdb:c10', 'not json');
    await profiles.setRawSetting(
      profileId,
      '${prefix}tmdb:c11',
      jsonEncode({
        'scope': 'w:synthetic',
        'excluded': true,
        'updatedAt': '2026-01-01T00:00:00.000Z',
      }),
    );
    await profiles.setRawSetting(
      profileId,
      '${prefix}tmdb:c12',
      jsonEncode({
        'scope': 'tmdb:c13',
        'excluded': true,
        'updatedAt': '2026-01-01T00:00:00.000Z',
      }),
    );
    await db
        .into(db.profileSettings)
        .insertOnConflictUpdate(
          ProfileSettingsCompanion.insert(
            profileId: profileId,
            key: '${prefix}tmdb:c14',
            value: jsonEncode({
              'scope': 'tmdb:c14',
              'excluded': 'true',
              'updatedAt': 'unknown',
            }),
          ),
        );
    final repo = FranchiseExclusionRepository(db);
    expect(await repo.activeScopes(profileId), isEmpty);
    expect(
      () => repo.exclude(
        profileId,
        const Title(id: 'local:1', kind: MediaKind.movie),
      ),
      throwsArgumentError,
    );
    expect(() => repo.restore(profileId, 'w:synthetic'), throwsArgumentError);
  });
}
