import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/features/deck/deck_controller.dart';
import 'package:cue/features/deck/deck_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';
import 'deck_test.dart' show settle, waitForDecisions;

class _AnimeOnly extends DeckFiltersController {
  @override
  DeckFilters build() => const DeckFilters(kinds: {MediaKind.anime});
}

const _orders = [
  'POPULARITY_DESC',
  'TRENDING_DESC',
  'SCORE_DESC',
  'FAVOURITES_DESC',
  'START_DATE_DESC',
];

/// AniList as an anime fan sees it: the popular pages are almost entirely
/// titles already in their library, while other orders still hold plenty
/// they have never seen. Synthetic ids only.
class _AnimeFanAniList extends FakeGateway {
  _AnimeFanAniList(this.library)
    : super(
        pages: {
          for (final kind in MediaKind.discoverable)
            if (kind != MediaKind.anime) kind: const [[]],
          MediaKind.anime: [
            [for (var i = 1; i <= 10; i++) item(i), ...library.take(40)],
            for (var p = 40; p < library.length; p += 50)
              library.skip(p).take(50).toList(),
          ],
        },
      ) {
    for (var o = 1; o < _orders.length; o++) {
      byOrder[_orders[o]] = [
        for (var p = 0; p < 3; p++)
          [
            // Each order overlaps the library heavily, as real orders do.
            ...library.skip(p * 30 + o * 7).take(30),
            for (var i = 0; i < 20; i++) item(10000 * o + p * 100 + i),
          ],
      ];
    }
  }

  final List<Map<String, dynamic>> library;
  final byOrder = <String, List<List<Map<String, dynamic>>>>{};

  @override
  List<String?> discoverSorts(MediaKind kind) =>
      kind == MediaKind.anime ? _orders : const [null];

  @override
  Future<CatalogPageDto> discover(
    MediaKind kind, {
    String? mood,
    int page = 1,
    String? sort,
  }) async {
    final list = byOrder[sort];
    if (kind != MediaKind.anime || list == null) {
      return super.discover(kind, mood: mood, page: page);
    }
    calls.add('discover:anime:${mood ?? '-'}:$page:$sort');
    if (page > list.length) return const CatalogPageDto([], false);
    return CatalogPageDto(
      list[page - 1].map(CatalogItemDto.new).toList(),
      page < list.length,
    );
  }
}

void main() {
  testWidgets(
    'an anime fan with a big imported library keeps getting anime past the first ten',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final library = [for (var i = 1001; i <= 1400; i++) item(i)];
      final gateway = _AnimeFanAniList(library);
      await t.runAsync(() async {
        final profile = (await ProfileRepository(db).ensureActive()).id;
        await CatalogRepository(
          db,
          gateway,
        ).upsert([for (final i in library) CatalogItemDto(i)]);
        await db.batch((b) {
          for (final i in library) {
            b.insert(
              db.userTitles,
              UserTitlesCompanion.insert(
                profileId: profile,
                titleId: 'anilist:${i['providerId']}',
                state: const Value('completed'),
                source: const Value('import:fan'),
                updatedAt: DateTime(2026, 1, 1),
              ),
            );
          }
        });
      });
      await pumpCue(
        t,
        db: db,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_AnimeOnly.new)],
      );
      await settle(t);
      final container = ProviderScope.containerOf(
        t.element(find.byType(DeckScreen)),
      );
      final libraryIds = {
        for (final i in library) 'anilist:${i['providerId']}',
      };
      final shown = <String>{};
      for (var i = 0; i < 30; i++) {
        final state = container.read(deckControllerProvider);
        expect(
          state.cards,
          isNotEmpty,
          reason: 'Anime supply must not end after ${shown.length} cards',
        );
        for (final card in state.cards) {
          expect(card.title.kind, MediaKind.anime);
          expect(libraryIds, isNot(contains(card.title.id)));
        }
        shown.add(state.top!.title.id);
        final choice = container
            .read(deckControllerProvider.notifier)
            .decide(Decision.notNow);
        await waitForDecisions(t, i + 1);
        await choice;
      }
      expect(shown.length, 30);
      // Supply came from orders beyond popularity, not invented titles.
      expect(
        gateway.calls.any(
          (c) => c.startsWith('discover:anime:') && c.endsWith('_DESC'),
        ),
        isTrue,
      );
    },
  );
}
