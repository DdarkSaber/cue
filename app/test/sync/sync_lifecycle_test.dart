import 'dart:async';

import 'package:cue/app/providers.dart';
import 'package:cue/sync/sync_controller.dart';
import 'package:cue/sync/sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

class _PausedCodes extends MemoryCodeStore {
  final started = Completer<void>();
  final finish = Completer<String?>();

  @override
  Future<String?> read(String profileId) {
    if (!started.isCompleted) started.complete();
    return finish.future;
  }
}

void main() {
  testWidgets(
    'disposing sync while secure-code load waits does not read a disposed ref',
    (tester) async {
      final db = memoryDb();
      addTearDown(db.close);
      final codes = _PausedCodes();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          codeStoreProvider.overrideWithValue(codes),
          catalogGatewayProvider.overrideWithValue(FakeGateway()),
        ],
      );
      container.read(syncControllerProvider);
      await tester.runAsync(() => codes.started.future);
      container.dispose();
      codes.finish.complete(null);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
