import 'dart:io';
import 'dart:math';

import 'package:cue/app/providers.dart';
import 'package:cue/imports/token_store.dart';
import 'package:cue/app/router.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/ranker.dart';
import 'package:cue/sync/sync_service.dart';
import 'package:cue/features/deck/swipe_tutorial.dart';
import 'package:cue/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Phone, tablet and desktop test viewports.
const phoneSmall = Size(360, 740);
const phoneLarge = Size(390, 844);
const desktop = Size(1440, 1000);

bool _fontsLoaded = false;

/// Loads bundled DM Sans so goldens show real glyphs instead of test boxes.
Future<void> loadCueFonts() async {
  if (_fontsLoaded) return;
  final loader = FontLoader('DM Sans');
  for (final w in ['Regular', 'Bold']) {
    final bytes = File('assets/fonts/DMSans-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
  _fontsLoaded = true;
}

Future<void> pumpCue(
  WidgetTester tester, {
  Size size = phoneLarge,
  double textScale = 1,
  bool disableAnimations = false,
  String location = CueRoutes.forYou,
  List<Override> overrides = const [],
  CueDatabase? db,
  FakeGateway? gateway,
  bool tutorial = false,
}) async {
  final database = db ?? memoryDb();
  if (db == null) addTearDown(database.close);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: disableAnimations);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        catalogGatewayProvider.overrideWithValue(gateway ?? sampleGateway()),
        // No platform keystore in tests; sync stays local.
        codeStoreProvider.overrideWithValue(MemoryCodeStore()),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        swipeTutorialEnabledProvider.overrideWithValue(tutorial),
        // Seeded so decks (and goldens) are the same every run.
        rankerProvider.overrideWithValue(Ranker(random: Random(7))),
        ...overrides,
      ],
      child: CueApp(router: buildRouter(initialLocation: location)),
    ),
  );
  await tester.pumpAndSettle();
}

/// A small synthetic catalog: anime and manhwa, two pages each.
FakeGateway sampleGateway() => FakeGateway(
  pages: {
    MediaKind.anime: [
      [
        for (var i = 1; i <= 12; i++)
          item(i, title: 'Anime', genres: const ['Action', 'Sports']),
      ],
      [
        for (var i = 13; i <= 20; i++)
          item(i, title: 'Anime', genres: const ['Comedy', 'Slice of Life']),
      ],
    ],
    MediaKind.manhwa: [
      [
        for (var i = 101; i <= 110; i++)
          item(
            i,
            title: 'Manhwa',
            kind: 'manhwa',
            country: 'KR',
            genres: const ['Romance', 'Drama'],
            episodes: null,
          ),
      ],
    ],
  },
);
