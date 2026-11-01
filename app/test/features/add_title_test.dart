import 'package:cue/app/providers.dart';
import 'package:cue/app/router.dart';
import 'package:cue/features/library/add_title_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';

void main() {
  testWidgets('Library can add a seen title from search', (tester) async {
    final gateway = sampleGateway()
      ..searchResults['frieren'] = [item(901, title: 'Frieren')];
    await pumpCue(tester, location: CueRoutes.library, gateway: gateway);
    await tester.tap(find.text('Add a title'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Frieren');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Frieren 901:'), findsOneWidget);

    final c = ProviderScope.containerOf(
      tester.element(find.byType(AddTitleButton)),
    );
    final id = await c.read(profileIdProvider.future);
    final entry = await c
        .read(libraryRepositoryProvider)
        .entry(id, 'anilist:901');
    expect(entry, isNotNull);
    // The same title now shows as already in the library.
    expect(find.text('In your library'), findsOneWidget);
    expect(find.text('Seen'), findsNothing);
  });
}
