import 'dart:math';

import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/ranker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cold unfiltered exploration samples unseen eligible formats early across seeds', () {
    final pool = [
      for (var i = 0; i < 40; i++)
        Title(
          id: 'reading:$i',
          titleEn: 'Invented reading $i',
          kind: MediaKind.manhwa,
          score: 95,
          year: 2025,
        ),
      for (final k in [
        MediaKind.anime,
        MediaKind.movie,
        MediaKind.series,
        MediaKind.kdrama,
      ])
        for (var i = 0; i < 5; i++)
          Title(
            id: '${k.name}:$i',
            titleEn: 'Invented ${k.name} $i',
            kind: k,
            score: 50,
            year: 2024,
          ),
    ];
    for (var seed = 0; seed < 30; seed++) {
      final deck = Ranker(random: Random(seed)).deal(
        pool,
        const ProfileSignals(),
        const DeckFilters(),
        showAdult: false,
        enabledKinds: {...MediaKind.discoverable},
        titlesById: {for (final t in pool) t.id: t},
      );
      expect(deck.length, 10);
      expect(
        deck.map((c) => c.title.kind).toSet().length,
        greaterThanOrEqualTo(4),
        reason: 'seed $seed',
      );
      expect(
        deck.take(3).map((c) => c.title.kind).toSet().length,
        2,
        reason: 'seed $seed',
      );
      expect(deck.first.title.kind, MediaKind.manhwa);
      final filtered = Ranker(random: Random(seed)).deal(
        pool,
        const ProfileSignals(),
        const DeckFilters(kinds: {MediaKind.movie}),
        showAdult: false,
        enabledKinds: {...MediaKind.discoverable},
        titlesById: {for (final t in pool) t.id: t},
      );
      expect(filtered.every((c) => c.title.kind == MediaKind.movie), isTrue);
    }
  });
}
