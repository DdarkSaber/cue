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

  testWidgets('an expired token is renewed once, then sign-in is asked for', (
    tester,
  ) async {
    final store = await pump(tester, token: 'old', refresh: 'rt');
    gateway
      ..rejectedTokens['old'] = 'token_expired'
      ..refreshError = 'token_expired';
    await tester.tap(find.text('Import again'));
    await tester.pumpAndSettle();
    expect(gateway.refreshCalls, ['rt']);
    expect(await store.read('mal'), isNull);
    expect(find.textContaining('sign-in expired'), findsOneWidget);
  });

  testWidgets(
    'an older Worker refusing the renewal with a bare 401 signs out',
    (tester) async {
      final store = await pump(tester, token: 'old', refresh: 'rt');
      gateway
        ..rejectedTokens['old'] = 'token_expired'
        ..refreshError = 'http_401';
      await tester.tap(find.text('Import again'));
      await tester.pumpAndSettle();
      expect(await store.read('mal'), isNull);
      expect(find.textContaining('sign-in expired'), findsOneWidget);
    },
  );

  for (final code in [
    'upstream_error',
    'rate_limited',
    'http_503',
    'unavailable',
    'bad_response',
    // A bare 401 on the list call is not proof the sign-in expired.
    'http_401',
  ]) {
    testWidgets('a $code from MyAnimeList keeps the sign-in', (tester) async {
      final store = await pump(tester, token: 'old', refresh: 'rt');
      gateway.rejectedTokens['old'] = code;
      await tester.tap(find.text('Import again'));
      await tester.pumpAndSettle();
      expect(gateway.refreshCalls, isEmpty);
      expect(await store.read('mal'), 'old');
      expect(await store.readRefresh('mal'), 'rt');
      expect(find.text('Import again'), findsOneWidget);
      expect(find.textContaining('Your sign-in is kept'), findsOneWidget);
      expect(find.textContaining('sign-in expired'), findsNothing);
    });
  }

  testWidgets('an outage while renewing keeps the sign-in', (tester) async {
    final store = await pump(tester, token: 'old', refresh: 'rt');
    gateway
      ..rejectedTokens['old'] = 'token_expired'
      ..refreshError = 'upstream_error';
    await tester.tap(find.text('Import again'));
    await tester.pumpAndSettle();
    expect(gateway.refreshCalls, ['rt']);
    expect(await store.read('mal'), 'old');
    expect(await store.readRefresh('mal'), 'rt');
    expect(find.textContaining('Your sign-in is kept'), findsOneWidget);
  });

  testWidgets('an outage on the early renewal still tries the kept token', (
    tester,
  ) async {
    final store = await pump(
      tester,
      token: 'old',
      refresh: 'rt',
      expiry: DateTime.now().add(const Duration(minutes: 10)),
    );
    gateway.refreshError = 'upstream_error';
    await tester.tap(find.text('Import again'));
    await tester.pumpAndSettle();
    expect(gateway.refreshCalls, ['rt']);
    expect(gateway.signedInCalls, ['old']);
    expect(await store.read('mal'), 'old');
  });
}
