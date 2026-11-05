import 'package:cue/features/imports/import_job.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

class _Running extends ImportJob {
  @override
  ImportJobState build() =>
      const ImportJobState(running: true, done: 3, total: 10);
}

class _Failed extends ImportJob {
  @override
  ImportJobState build() =>
      const ImportJobState(error: 'Matching stopped. Try the import again.');
}

void main() {
  testWidgets('the deck shows a running import and links to it', (t) async {
    await pumpCue(t, overrides: [importJobProvider.overrideWith(_Running.new)]);
    expect(find.text('Matching your import: 3 of 10 · Open'), findsOneWidget);
    await t.tap(find.text('Matching your import: 3 of 10 · Open'));
    // The progress skeleton shimmers until matching ends, so the screen
    // never settles; step past the route transition instead.
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('Matching 3 of 10'), findsOneWidget);
  });

  testWidgets('a failed import says so on the deck', (t) async {
    await pumpCue(t, overrides: [importJobProvider.overrideWith(_Failed.new)]);
    expect(find.textContaining('Matching stopped'), findsOneWidget);
  });

  testWidgets('no import, no banner', (t) async {
    await pumpCue(t);
    expect(find.textContaining('your import'), findsNothing);
  });
}
