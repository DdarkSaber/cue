import 'dart:async';

import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/imports/import_service.dart';
import 'package:cue/imports/records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';

void main() {
  for (final kind in [MediaKind.anime, MediaKind.manhwa]) {
    testWidgets(
      'review finds a cached deck ${kind.name} offline, confirms only on choice',
      (t) async {
        final db = memoryDb();
        addTearDown(db.close);
        final gateway = FakeGateway(offline: true);
        final catalog = CatalogRepository(db, gateway);
        final service = ImportService(db, catalog);
        late String profile;
        const name = 'Invented Explorer';
        await t.runAsync(() async {
          profile = (await ProfileRepository(db).create()).id;
          await service.commit(
            profile,
            await service.stage(
              profile,
              ParsedImport(
                sourceType: 'generic_csv',
                adapterVersion: '1',
                records: [
                  NormalizedRecord(
                    sourceEntryKey: 'queued',
                    title: name,
                    kind: kind,
                  ),
                ],
              ),
              offlineOnly: true,
            ),
          );
          // A later recommendation introduces the same work to the local catalog.
          await catalog.upsert([
            CatalogItemDto({
              ...item(91, kind: kind.name),
              'titleEn': name,
              'titleRomaji': 'Sorairo no Tabi',
            }),
          ]);
        });
        await pumpCue(
          t,
          db: db,
          gateway: gateway,
          location: '/settings/library/$profile',
          size: desktop,
        );
        await t.tap(find.text(name));
        await t.pumpAndSettle();
        expect(find.byType(Checkbox), findsOneWidget);
        expect(find.textContaining('available matches'), findsOneWidget);
        await t.runAsync(() async {
          expect(await service.reviewQueue(profile), hasLength(1));
          expect(
            await LibraryRepository(db).entry(profile, 'anilist:91'),
            isNull,
          );
        });
        await t.ensureVisible(find.byType(Checkbox));
        await t.tap(find.byType(Checkbox));
        await t.pump();
        await t.ensureVisible(find.text('Link this title'));
        await t.tap(find.text('Link this title'));
        await t.pumpAndSettle();
        await t.runAsync(() async {
          expect(await service.reviewQueue(profile), isEmpty);
          expect(
            await LibraryRepository(db).entry(profile, 'anilist:91'),
            isNotNull,
          );
        });
      },
    );
  }

  testWidgets('a late initial review search cannot replace a newer query', (
    t,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    final gateway = _DelayedSearch();
    late String profile;
    await t.runAsync(() async {
      profile = (await ProfileRepository(db).create()).id;
      final service = ImportService(db, CatalogRepository(db, gateway));
      await service.commit(
        profile,
        await service.stage(
          profile,
          const ParsedImport(
            sourceType: 'generic_csv',
            adapterVersion: '1',
            records: [
              NormalizedRecord(
                sourceEntryKey: 'queued',
                title: 'Invented first query',
              ),
            ],
          ),
          offlineOnly: true,
        ),
      );
    });
    await pumpCue(
      t,
      db: db,
      gateway: gateway,
      location: '/settings/library/$profile',
      size: desktop,
    );
    await t.tap(find.text('Invented first query'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(find.byType(TextField).last, 'Invented new query');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(find.text('Invented latest result'), findsOneWidget);
    gateway.first.complete([
      CatalogItemDto({...item(8), 'titleEn': 'Invented stale result'}),
    ]);
    await t.pumpAndSettle();
    expect(find.text('Invented latest result'), findsOneWidget);
    expect(find.text('Invented stale result'), findsNothing);
  });
}

class _DelayedSearch extends FakeGateway {
  final first = Completer<List<CatalogItemDto>>();
  @override
  Future<List<CatalogItemDto>> search(String query, {MediaKind? kind}) async {
    if (query == 'Invented first query') return first.future;
    return [
      CatalogItemDto({...item(9), 'titleEn': 'Invented latest result'}),
    ];
  }
}
