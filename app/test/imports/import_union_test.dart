import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/library.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/import_union.dart';

void main() {
  test('Excel and MAL form one deduplicated, profile-scoped history', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final fixture = await seedImportUnion(db);
    final library = LibraryRepository(db);
    final signals = await library.signals(fixture.profile);
    expect(signals.library.keys.toSet(), fixture.historyIds);
    expect(signals.library['anilist:1']!.rating, Rating.wouldRewatch);
    expect(signals.library['anilist:1']!.state, LibraryState.completed);
    expect(signals.library['anilist:2']!.state, LibraryState.watching);
    expect(signals.library['anilist:3']!.state, LibraryState.caughtUp);
    expect(signals.library['anilist:4']!.state, LibraryState.reading);
    expect(signals.library['anilist:5']!.state, LibraryState.planned);
    expect(signals.library['anilist:6']!.state, LibraryState.completed);
    final other = await ProfileRepository(db).create();
    expect((await library.signals(other.id)).library, isEmpty);
    expect((await library.signals(fixture.profile)).library, hasLength(7));
  });
}
