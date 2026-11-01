import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/common.dart' show Failure;
import 'package:integration_test/integration_test.dart';
// Flutter's integration binding reports only testWidgets; include plain test()
// outcomes from the same runner, without changing or duplicating test bodies.
// ignore: depend_on_referenced_packages, implementation_imports
import 'package:test_api/src/backend/invoker.dart';

class SyntheticWebTestBinding extends IntegrationTestWidgetsFlutterBinding {
  @override
  bool get registerTestTextInput => true;

  final _widgetDescriptions = <String>{};
  final _outcomes = <String, bool>{};

  void recordAllTests() {
    setUp(() {
      final live = Invoker.current!.liveTest;
      live.onError.listen((error) {
        if (_widgetDescriptions.contains(live.individualName)) return;
        results[live.test.name] = Failure(
          live.test.name,
          '${error.error}\n${error.stackTrace}',
        );
      });
      addTearDown(() {
        _outcomes[live.test.name] = live.state.result.isPassing;
      });
    });
  }

  @override
  Future<void> runTest(
    Future<void> Function() testBody,
    VoidCallback invariantTester, {
    String description = '',
    Duration? timeout,
  }) async {
    _widgetDescriptions.add(description);
    await super.runTest(testBody, invariantTester, description: description);
  }

  Map<String, Object> outcomeReport() {
    for (final failure in failureMethodsDetails) {
      for (final name in _outcomes.keys.toList()) {
        if (name == failure.methodName ||
            name.endsWith(' ${failure.methodName}')) {
          _outcomes[name] = false;
        }
      }
    }
    final widgetCount = _widgetDescriptions.length;
    final widgetFailures = failureMethodsDetails
        .where((failure) => _widgetDescriptions.contains(failure.methodName))
        .length;
    return {
      'syntheticOnly': true,
      'total': _outcomes.length,
      'passed': _outcomes.values.where((passed) => passed).length,
      'failed': _outcomes.values.where((passed) => !passed).length,
      'widgetTests': widgetCount,
      'widgetFailures': widgetFailures,
      'plainTests': _outcomes.length - widgetCount,
      'tests': {
        for (final entry in _outcomes.entries)
          entry.key: entry.value ? 'passed' : 'failed',
      },
    };
  }
}
