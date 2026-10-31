import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards for platform files that the Dart analyzer does not see.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();
  final index = File('web/index.html').readAsStringSync();
  final headers = File('web/_headers').readAsStringSync();

  test('Android: local library is excluded from backups', () {
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(manifest, contains('android:dataExtractionRules='));
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml')
        .readAsStringSync();
    expect('<cloud-backup>'.allMatches(rules), hasLength(1));
    expect('<device-transfer>'.allMatches(rules), hasLength(1));
  });

  test('Android: app id and no cleartext opt-in', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "app.cue.next"'));
    expect(manifest, isNot(contains('usesCleartextTraffic="true"')));
  });

  test('Android: launch and window background are the Cinema bg', () {
    for (final f in [
      'android/app/src/main/res/values/styles.xml',
      'android/app/src/main/res/values-night/styles.xml',
      'android/app/src/main/res/drawable/launch_background.xml',
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ]) {
      final s = File(f).readAsStringSync();
      expect(s, isNot(contains('white')), reason: f);
      expect(s, isNot(contains('colorBackground')), reason: f);
    }
    expect(
      File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
      contains('#080A0D'),
    );
  });

  test('web: language, CSP and no remote hosts in the shell', () {
    expect(index, contains('<html lang="en">'));
    expect(index, contains('Content-Security-Policy'));
    expect(index, isNot(contains('http://')));
    expect(index, isNot(contains('https://')));
    for (final h in [
      "frame-ancestors 'none'",
      'X-Content-Type-Options: nosniff',
      'Strict-Transport-Security',
      'Referrer-Policy: no-referrer',
    ]) {
      expect(headers, contains(h));
    }
  });
}
