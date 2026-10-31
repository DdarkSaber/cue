import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/features/library/library_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const manhwa = Title(id: 'a', kind: MediaKind.manhwa, chapters: 120);

  test('counts chapters past the last one read', () {
    const e = LibraryEntry(titleId: 'a', progressValue: 115);
    expect(newChapters(e, manhwa), 5);
  });

  test('uses the larger of catalog and source totals', () {
    const e = LibraryEntry(titleId: 'a', progressValue: 115, latestKnown: 130);
    expect(newChapters(e, manhwa), 15);
  });

  test('unknown totals or progress show no badge, never zero', () {
    const ongoing = Title(id: 'b', kind: MediaKind.manhwa);
    expect(
      newChapters(const LibraryEntry(titleId: 'b', progressValue: 10), ongoing),
      isNull,
    );
    expect(newChapters(const LibraryEntry(titleId: 'a'), manhwa), isNull);
    expect(
      newChapters(const LibraryEntry(titleId: 'a', progressValue: 120), manhwa),
      isNull,
    );
  });

  test('anime never gets a chapter badge', () {
    const anime = Title(id: 'c', kind: MediaKind.anime, episodes: 24);
    expect(
      newChapters(const LibraryEntry(titleId: 'c', progressValue: 3), anime),
      isNull,
    );
  });
}
