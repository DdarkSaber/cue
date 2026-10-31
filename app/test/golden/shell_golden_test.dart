@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  setUpAll(loadCueFonts);

  for (final (name, size) in [
    ('phone_360x740', phoneSmall),
    ('phone_390x844', phoneLarge),
    ('desktop_1440x1000', desktop),
  ]) {
    testWidgets('shell $name', (t) async {
      await pumpCue(t, size: size);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/shell_$name.png'),
      );
    });
  }
}
