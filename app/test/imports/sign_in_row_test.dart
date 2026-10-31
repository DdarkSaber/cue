import 'package:cue/app/providers.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/features/imports/sign_in_import.dart';
import 'package:cue/imports/token_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  Future<MemoryTokenStore> pump(WidgetTester tester, {String? token}) async {
    final store = MemoryTokenStore();
    if (token != null) await store.write('mal', token);
    final gateway = FakeGateway()..config = const OAuthConfigDto(mal: 'id');
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogGatewayProvider.overrideWithValue(gateway),
          tokenStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SignInSourceRow(
                provider: SignInProvider.mal,
                onRecords: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('MyAnimeList'));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('with no kept sign-in it offers to sign in', (tester) async {
    await pump(tester);
    expect(find.text('Sign in with MyAnimeList'), findsOneWidget);
    expect(find.text('Import again'), findsNothing);
  });

  testWidgets('a kept sign-in survives reopening and can be removed', (
    tester,
  ) async {
    final store = await pump(tester, token: 'kept-token');
    expect(find.text('Import again'), findsOneWidget);
    expect(find.text('Sign in with MyAnimeList'), findsNothing);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(await store.read('mal'), isNull);
    expect(find.text('Sign in with MyAnimeList'), findsOneWidget);
  });
}
