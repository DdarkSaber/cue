// Flutter's web compiler roots relative imports at the target's directory.
// Keep this entrypoint at the app root so integration_test can reuse test fixtures.
// Set CUE_WEB_E2E_ALLOW_DEBUG_SCRIPTS=true only for an isolated localhost driver.
// flutter drive --driver=test_driver/integration_test.dart \
//   --target=web_integration_test.dart -d web-server --browser-name=chrome \
//   --headless --no-web-resources-cdn --chrome-binary=<isolated Chrome>
// For unchanged production CSP, use web_persistence_integration_test.dart with
// --release and without the debug-script environment flag.
import 'integration_test/web_flow_test.dart' as suite;

void main() => suite.main();
