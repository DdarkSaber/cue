import 'package:cue/app/router.dart';
import 'package:cue/features/imports/import_screen.dart';
import 'package:cue/features/library/library_screen.dart';
import 'package:cue/features/library/rating_deck.dart';
import 'package:cue/imports/import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers.dart';

void main() {
  /// Pumps the app on the importer and returns its router.
  Future<GoRouter> openImporter(WidgetTester tester) async {
    await pumpCue(tester, location: CueRoutes.importer);
    return GoRouter.of(tester.element(find.byType(ImportScreen)));
  }

  testWidgets('tapping a tab opens its main page, not a parked sub-page', (
    tester,
  ) async {
    final router = await openImporter(tester);
    router.go(CueRoutes.forYou);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    // Tabs now always open on their main page.
    expect(find.byType(ImportScreen), findsNothing);
  });

  testWidgets('resetting the Library stack first reopens the Library list', (
    tester,
  ) async {
    final router = await openImporter(tester);
    router.go(CueRoutes.library);
    await tester.pumpAndSettle();
    router.go(CueRoutes.forYou);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    expect(find.byType(ImportScreen), findsNothing);
    expect(find.byType(LibraryScreen), findsOneWidget);
  });

  testWidgets(
    'summary "Rate titles in Library" opens the rating deck; exit lands in Library',
    (tester) async {
      await openImporter(tester);
      tester
          .state<ImportScreenState>(find.byType(ImportScreen))
          .debugShowSummary(
            const ImportSummary(
              batchId: null,
              checked: 3,
              added: 3,
              updated: 0,
              unchanged: 0,
              review: 0,
            ),
          );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rate titles in Library'));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryRatingDeck), findsOneWidget);
      expect(find.text('Rate your library'), findsOneWidget);
      await tester.tap(find.byTooltip('Exit rating'));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryRatingDeck), findsNothing);
      expect(find.byType(ImportScreen), findsNothing);
      expect(find.byType(LibraryScreen), findsOneWidget);
    },
  );

  testWidgets('summary with titles to review still links to the review', (
    tester,
  ) async {
    await openImporter(tester);
    tester
        .state<ImportScreenState>(find.byType(ImportScreen))
        .debugShowSummary(
          const ImportSummary(
            batchId: null,
            checked: 3,
            added: 1,
            updated: 0,
            unchanged: 0,
            review: 2,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('Rate titles in Library'), findsNothing);
    await tester.tap(find.text('Review 2 in Library'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryRatingDeck), findsNothing);
    expect(find.byType(LibraryScreen), findsOneWidget);
  });

  testWidgets('Settings reopens on its main page after visiting a sub-page', (
    tester,
  ) async {
    await pumpCue(tester, location: '/settings/privacy');
    expect(find.text('Clear mood learning'), findsWidgets);
    await tester.tap(find.text('For you').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Privacy and data'), findsOneWidget);
    expect(find.text('Clear mood learning'), findsNothing);
  });
}
