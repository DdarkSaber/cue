import 'dart:convert';

import 'package:cue/diagnostics/technical_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

class _EphemeralConsent implements DiagnosticConsentStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

/// Real Flutter HTTP -> owned local Worker/D1. Never points at production;
/// the random capability remains in this test's memory and is not logged.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'actual consent-gated client uploads and authenticated export roundtrip',
    (t) async {
      const base = String.fromEnvironment(
        'CUE_DIAGNOSTICS_TEST_API',
        defaultValue: 'http://10.0.2.2:8787',
      );
      final uri = Uri.parse(base);
      expect({'10.0.2.2', '127.0.0.1', 'localhost'}, contains(uri.host));
      final store = _EphemeralConsent();
      var diagnostics = TechnicalDiagnostics(base, store);
      addTearDown(() => diagnostics.dispose());
      await diagnostics.load();
      expect(
        diagnostics.begin(
          DiagnosticProvider.local,
          DiagnosticOperation.settings,
        ),
        isNull,
      );
      await diagnostics.setEnabled(true);
      final ticket = diagnostics.begin(
        DiagnosticProvider.local,
        DiagnosticOperation.settings,
      );
      diagnostics.finish(ticket, DiagnosticStatus.ok, DiagnosticError.none);
      await diagnostics.upload();
      expect(
        diagnostics.pendingCount,
        0,
        reason: 'Actual local upload must succeed',
      );
      final document = jsonDecode(await diagnostics.export()) as Map;
      final event = (document['events'] as List).single as Map;
      expect(event.keys.toSet(), {
        'requestId',
        'appVersion',
        'provider',
        'operation',
        'durationMs',
        'status',
        'errorCode',
      });
      expect(event['operation'], 'settings');
      expect(event['status'], 'ok');
      expect(document.containsKey('token'), isFalse);
      final oldCode = diagnostics.recoveryCode!;
      final oldId = diagnostics.sessionId!;
      final deadline = diagnostics.expiresAt;
      diagnostics.dispose();
      diagnostics = TechnicalDiagnostics(base, store);
      await diagnostics.load();
      expect(diagnostics.enabled, isTrue);
      expect(diagnostics.recoveryCode == oldCode, isTrue);
      expect(diagnostics.expiresAt, deadline);
      final pending = diagnostics.begin(
        DiagnosticProvider.local,
        DiagnosticOperation.import,
      );
      await diagnostics.setEnabled(false);
      diagnostics.finish(
        pending,
        DiagnosticStatus.failed,
        DiagnosticError.network,
      );
      expect(diagnostics.pendingCount, 0);
      expect(diagnostics.enabled, isFalse);
      expect(
        (jsonDecode(await diagnostics.export()) as Map)['events'],
        hasLength(1),
      );
      await diagnostics.setEnabled(true);
      expect(diagnostics.recoveryCode, isNull);
      diagnostics.finish(
        diagnostics.begin(
          DiagnosticProvider.local,
          DiagnosticOperation.settings,
        ),
        DiagnosticStatus.ok,
        DiagnosticError.none,
      );
      await diagnostics.upload();
      expect(diagnostics.pendingCount, 0);
      expect(diagnostics.recoveryCode != oldCode, isTrue);
      expect(diagnostics.sessionId != oldId, isTrue);
      final oldResponse = await http.get(
        Uri.parse('$base/diagnostics/$oldId'),
        headers: {'Authorization': 'Bearer $oldCode'},
      );
      expect(oldResponse.statusCode, 200);
      expect((jsonDecode(oldResponse.body) as Map)['events'], hasLength(1));
      final crossResponse = await http.get(
        Uri.parse('$base/diagnostics/${diagnostics.sessionId}'),
        headers: {'Authorization': 'Bearer $oldCode'},
      );
      expect(crossResponse.statusCode, 403);
      expect(
        (jsonDecode(await diagnostics.export()) as Map)['events'],
        hasLength(1),
      );
    },
  );
}
