import 'package:cue/app/providers.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/features/details/details_sheet.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late CueDatabase db;
  late String profileId;
  setUp(() async {
    db = memoryDb();
    profileId = (await ProfileRepository(db).ensureActive()).id;
  });
  tearDown(() => db.close());

  Future<void> mount(WidgetTester t, Title title) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          catalogGatewayProvider.overrideWithValue(FakeGateway()),
          profileIdProvider.overrideWith((ref) async => profileId),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DetailsBody(title: title)),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  /// The value beside "Length" in the Details facts.
  String? lengthFact(WidgetTester t) {
    final label = find.text('Length');
    if (label.evaluate().isEmpty) return null;
    final row = find.ancestor(of: label, matching: find.byType(Row)).first;
    final texts = t.widgetList<Text>(
      find.descendant(of: row, matching: find.byType(Text)),
    );
    return texts.map((x) => x.data).firstWhere((d) => d != 'Length');
  }

  testWidgets('manhwa shows its chapters, ongoing with a plus', (t) async {
    await mount(
      t,
      const Title(
        id: 'local:m',
        kind: MediaKind.manhwa,
        titleEn: 'Synthetic manhwa',
        chapters: 120,
        status: 'ongoing',
      ),
    );
    expect(lengthFact(t), 'Ongoing · 120+ chapters');
  });

  testWidgets('manga without a count says chapters are unknown', (t) async {
    await mount(
      t,
      const Title(id: 'local:g', kind: MediaKind.manga, titleEn: 'Synthetic'),
    );
    expect(lengthFact(t), 'Chapters unknown');
  });

  testWidgets('anime shows seasons and episodes', (t) async {
    await mount(
      t,
      const Title(
        id: 'local:a',
        kind: MediaKind.anime,
        titleEn: 'Synthetic anime',
        episodes: 24,
        seasons: [
          Season(number: 1, episodes: 24),
          Season(number: 2, episodes: 24),
          Season(number: 3, episodes: 16),
        ],
      ),
    );
    expect(lengthFact(t), '3 seasons · 64 episodes');
  });

  testWidgets('a K-drama with one season shows its episodes', (t) async {
    await mount(
      t,
      const Title(
        id: 'local:k',
        kind: MediaKind.kdrama,
        titleEn: 'Synthetic drama',
        episodes: 16,
      ),
    );
    expect(lengthFact(t), '16 episodes');
  });

  testWidgets('movies list no length', (t) async {
    await mount(
      t,
      const Title(id: 'local:f', kind: MediaKind.movie, titleEn: 'Synthetic'),
    );
    expect(find.text('Length'), findsNothing);
  });
}
