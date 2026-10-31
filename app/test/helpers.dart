import 'dart:io';

import 'package:cue/app/router.dart';
import 'package:cue/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

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
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: disableAnimations);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: CueApp(router: buildRouter(initialLocation: location)),
    ),
  );
  await tester.pumpAndSettle();
}
