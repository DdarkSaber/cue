import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  if (Platform.environment['CUE_WEB_E2E_ALLOW_DEBUG_SCRIPTS'] == 'true') {
    await _allowDebugScriptsInIsolatedLocalTest();
  }
  await integrationDriver(writeResponseOnFailure: true);
}

Future<void> _allowDebugScriptsInIsolatedLocalTest() async {
  final environment = Platform.environment;
  final driver = Uri.parse(environment['DRIVER_SESSION_URI']!);
  final page = Uri.parse(environment['VM_SERVICE_URL']!);
  final session = environment['DRIVER_SESSION_ID']!;
  bool local(Uri uri) => ['localhost', '127.0.0.1', '::1'].contains(uri.host);
  if (environment['FLUTTER_WEB_TEST'] != 'true' ||
      !local(driver) ||
      !local(page) ||
      !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(session)) {
    throw StateError('Debug script allowance requires a local WebDriver test.');
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    Future<void> command(String action, Map<String, Object> body) async {
      final request = await client.postUrl(
        driver.replace(path: '/session/$session/$action'),
      );
      request.headers.contentType = ContentType.json;
      final bytes = utf8.encode(jsonEncode(body));
      request.contentLength = bytes.length;
      request.add(bytes);
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final result = jsonDecode(await utf8.decoder.bind(response).join());
      if (response.statusCode != HttpStatus.ok ||
          (result['value'] is Map && result['value']['error'] != null)) {
        throw StateError('Local browser debug setup failed: $action: $result.');
      }
    }

    // Only the isolated test page needs DWDS's inline/eval debug scripts.
    // Production CSP remains unchanged; release smoke runs must omit this flag.
    await command('chromium/send_command', {
      'cmd': 'Page.setBypassCSP',
      'params': {'enabled': true},
    });
    await command('refresh', {});
  } finally {
    client.close(force: true);
  }
}
