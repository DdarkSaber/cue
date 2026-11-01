import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/common.dart' show Failure;

import '../test/features/library_browser_test.dart' as browser;
import '../test/features/library_settings_test.dart' as settings;
import '../test/features/recommendation_history_test.dart' as recommendations;
import '../test/features/followup_flow_test.dart' as followup;
import '../test/features/deck_test.dart' as deck;
import '../test/features/library_rating_flow_test.dart' as ratings;
import '../test/data/library_rating_service_test.dart' as rating_service;
import '../test/features/daily_session_flow_test.dart' as daily_session;
import '../test/domain/recommendation_context_test.dart' as session_context;
import '../test/data/catalog_budget_test.dart' as catalog_budget;
import '../test/data/franchise_exclusion_test.dart' as franchise_data;
import '../test/features/details_actions_test.dart' as details_actions;
import '../test/features/franchise_exclusions_section_test.dart'
    as franchise_settings;
import '../test/features/try_now_flow_test.dart' as try_now_flow;
import '../test/features/try_now_gesture_test.dart' as try_now_gesture;
import '../test/domain/try_now_intent_test.dart' as try_now_intent;
import '../test/diagnostics/capability_lifecycle_test.dart' as capabilities;
import '../test/support/test_database_web.dart';
import 'web_persistence_test.dart' as persistence;
import 'web_test_binding.dart';
import 'diagnostics_local_test.dart' as diagnostics_local;

void main() {
  final binding = SyntheticWebTestBinding();
  binding.recordAllTests();
  beforeSyntheticDatabaseClose = () async {
    // Live integration tests keep the last app mounted between test cases.
    // Dispose its provider listeners before closing their WASM connection.
    binding.attachRootWidget(const SizedBox.shrink());
    binding.scheduleFrame();
    await Future<void>.delayed(const Duration(milliseconds: 200));
  };
  final previousReporter = reportTestException;
  reportTestException = (details, description) {
    previousReporter(details, description);
    // FlutterErrorDetails.toString() is empty in release-mode browser builds.
    binding.results[description] = Failure(
      description,
      '${details.exceptionAsString()}\n${details.stack ?? ''}',
    );
  };
  tearDownAll(() async {
    binding.reportData = binding.outcomeReport();
    await deleteAllSyntheticDatabases();
    binding.reportData!['syntheticStorageCleanup'] = 'verified';
  });
  if (const String.fromEnvironment('CUE_WEB_E2E_GROUP') == 'diagnostics') {
    group('web diagnostics lifecycle', capabilities.main);
    group('web local Worker capability isolation', diagnostics_local.main);
    group('web diagnostics Settings and follow-up', followup.main);
    return;
  }
  if (const String.fromEnvironment('CUE_WEB_E2E_GROUP') == 'ratings') {
    group('web optional rating cards', ratings.main);
    return;
  }
  if (const String.fromEnvironment('CUE_WEB_E2E_GROUP') == 'release_deck') {
    group('web release deck persistence', () {
      deck.main(releasePersistenceOnly: true);
    });
    return;
  }
  if (const String.fromEnvironment('CUE_WEB_E2E_GROUP') ==
      'release_persistence') {
    group('web SQLite import persistence', persistence.main);
    group('web optional rating cards', ratings.main);
    group('web rating persistence and Try now cleanup', rating_service.main);
    group('web bounded session context', session_context.main);
    group('web catalog request budget', catalog_budget.main);
    group('web franchise persistence', franchise_data.main);
    group('web details actions', details_actions.main);
    group('web franchise Settings', franchise_settings.main);
    group('web Try now flow', try_now_flow.main);
    group('web Try now intent persistence', try_now_intent.main);
    return;
  }
  group('web SQLite import persistence', persistence.main);
  group('web library browsing', browser.main);
  group('web settings', settings.main);
  group('web merged history', recommendations.main);
  group('web follow-up flows', followup.main);
  group('web swipe and undo', deck.main);
  group('web optional rating cards', ratings.main);
  group('web rating persistence and Try now cleanup', rating_service.main);
  group('web daily session controls', daily_session.main);
  group('web bounded session context', session_context.main);
  group('web catalog request budget', catalog_budget.main);
  group('web franchise persistence', franchise_data.main);
  group('web details actions', details_actions.main);
  group('web franchise Settings', franchise_settings.main);
  group('web Try now flow', try_now_flow.main);
  group('web Try now gestures', try_now_gesture.main);
  group('web Try now intent persistence', try_now_intent.main);
}
