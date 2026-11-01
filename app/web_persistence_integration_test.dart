import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'integration_test/web_persistence_test.dart' as persistence;
import 'test/support/test_database_web.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  tearDownAll(() async {
    await deleteAllSyntheticDatabases();
    binding.reportData = {
      'syntheticOnly': true,
      'syntheticStorageCleanup': 'verified',
      'passed': binding.failureMethodsDetails.isEmpty ? 1 : 0,
      'failed': binding.failureMethodsDetails.length,
    };
  });
  persistence.main();
}
