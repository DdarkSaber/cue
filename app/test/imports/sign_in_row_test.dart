import 'package:cue/app/providers.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/features/imports/sign_in_import.dart';
import 'package:cue/imports/token_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late FakeGateway gateway;

  Future<MemoryTokenStore> pump(
    WidgetTester tester, {
    String? token,
    String? refresh,
    DateTime? expiry,
  }) async {
    final store = MemoryTokenStore();
    if (token != null) await store.write('mal', token);
    if (refresh != null) await store.writeRefresh('mal', refresh);
    if (expiry != null) await store.writeExpiry('mal', expiry);
    gateway = FakeGateway()..config = const OAuthConfigDto(mal: 'id');
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

  testWidgets('an expired sign-in is renewed before Import again', (
    tester,
  ) async {
    final store = await pump(
      tester,
      token: 'old',
      refresh: 'rt',
      expiry: DateTime.now().subtract(const Duration(days: 1)),
    );
    await tester.tap(find.text('Import again'));
    await tester.pumpAndSettle();
    expect(gateway.refreshCalls, ['rt']);
    expect(gateway.signedInCalls, ['renewed']);
    expect(await store.read('mal'), 'renewed');
    expect(await store.readRefresh('mal'), 'refresh2');
  });

  testWidgets('a refused token is renewed once, then sign-in is asked for', (
    tester,
  ) async {
    final store = await pump(tester, token: 'old', refresh: 'rt');
    gateway
      ..rejectedTokens.add('old')
      ..refreshFails = true;
    await tester.tap(find.text('Import again'));
    await tester.pumpAndSettle();
    expect(gateway.refreshCalls, ['rt']);
    expect(await store.read('mal'), isNull);
    expect(find.textContaining('sign-in expired'), findsOneWidget);
  });
}
