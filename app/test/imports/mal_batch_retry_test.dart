import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/imports/matcher.dart';
import 'package:cue/imports/records.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

// A MAL list is matched by MAL id in batches of 50. A refused batch used to
// abort the whole match and leave every later title "not checked".
void main() {
  group('MAL id batches', () {
    NormalizedRecord malRec(int id) => NormalizedRecord(
      sourceEntryKey: 'mal:anime:$id',
      title: 'Synthetic $id',
      kind: MediaKind.anime,
      malId: id,
      state: LibraryState.completed,
    );

    Future<List<MatchedRecord>> run(
      _FlakyMalGateway gateway,
      List<Duration> waits,
    ) async {
      final db = memoryDb();
      addTearDown(db.close);
      for (var id = 1; id <= 60; id++) {
        gateway.malCatalog[id] = item(1000 + id, idMal: id);
      }
      return ImportMatcher(
        CatalogRepository(db, gateway),
        sleep: (d) async => waits.add(d),
      ).match([for (var id = 1; id <= 60; id++) malRec(id)]);
    }

    test('a busy batch is retried and still matches by id', () async {
      final waits = <Duration>[];
      final m = await run(_FlakyMalGateway(failures: 1), waits);
      expect(m.where((r) => r.matchClass == MatchClass.exactId), hasLength(60));
      expect(m.where((r) => r.unchecked), isEmpty);
      expect(waits, [ImportMatcher.retryWaits.first]);
    });

    test('one batch that keeps failing never stops the others', () async {
      final waits = <Duration>[];
      final m = await run(
        _FlakyMalGateway(failures: 99, onlyWith: 1, code: 'upstream_error'),
        waits,
      );
      // The second batch (ids 51-60) still matched by id.
      expect(
        m.skip(50).every((r) => r.matchClass == MatchClass.exactId),
        isTrue,
      );
      // The failed batch went on to the name passes instead of being
      // dropped as "not checked".
      expect(m.take(50).where((r) => r.unchecked), isEmpty);
      expect(waits, ImportMatcher.retryWaits);
    });

    test('a rate limit AniList already retried is not retried again', () async {
      final waits = <Duration>[];
      final gateway = _FlakyMalGateway(failures: 99, onlyWith: 1, spent: true);
      final m = await run(gateway, waits);
      // One call for the refused batch, none stacked on top of it.
      expect(gateway.refused, 1);
      expect(waits, isEmpty);
      expect(
        m.skip(50).every((r) => r.matchClass == MatchClass.exactId),
        isTrue,
      );
      expect(m.take(50).where((r) => r.unchecked), isEmpty);
    });

    test('a Worker rate limit with retries left is still retried', () async {
      final waits = <Duration>[];
      final m = await run(_FlakyMalGateway(failures: 1), waits);
      expect(m.where((r) => r.matchClass == MatchClass.exactId), hasLength(60));
      expect(waits, [ImportMatcher.retryWaits.first]);
    });
  });
}

/// Refuses MAL-id batches (as AniList does when busy) a set number of times;
/// with [onlyWith], only batches holding that MAL id.
class _FlakyMalGateway extends FakeGateway {
  _FlakyMalGateway({
    required this.failures,
    this.onlyWith,
    this.code = 'rate_limited',
    this.spent = false,
  });
  int failures;
  final int? onlyWith;
  final String code;

  /// The refusal comes after the AniList client's own 429 retries.
  final bool spent;
  int refused = 0;

  @override
  Future<MatchResponse> match(
    List<MatchQuery> items, {
    List<int> malAnime = const [],
    List<int> malManga = const [],
  }) async {
    final hit = onlyWith == null || malAnime.contains(onlyWith);
    if (malAnime.isNotEmpty && hit && failures > 0) {
      failures--;
      refused++;
      throw CatalogUnavailable(code, retriesSpent: spent);
    }
    return super.match(items, malAnime: malAnime, malManga: malManga);
  }
}
