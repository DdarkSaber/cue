import 'dart:convert';

import 'package:cue/sync/sync_controller.dart';
import 'package:cue/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  HttpSyncRemote remote(int status, String body) => HttpSyncRemote(
    'https://worker.test',
    client: MockClient((_) async => http.Response(body, status)),
  );

  Future<String> code(Future<Object?> Function() call) async {
    try {
      await call();
    } on SyncFailed catch (e) {
      return e.code;
    }
    fail('expected SyncFailed');
  }

  test('full storage is quota, with a clear sentence', () async {
    final r = remote(429, jsonEncode({'error': 'quota_exceeded'}));
    expect(await code(() => r.put('id', 't', 0, 'x')), 'quota');
    expect(await code(() => r.get('id', 't')), 'quota');
    expect(
      syncMessage(const SyncFailed('quota')),
      'Sync storage is full right now; your library is safe on this device. '
      'Try again tomorrow.',
    );
  });

  test('a plain rate limit keeps its status', () async {
    final r = remote(429, jsonEncode({'error': 'rate_limited'}));
    expect(await code(() => r.put('id', 't', 0, 'x')), 'http_429');
  });

  test('a wrong token answers 404 and reads as no copy', () async {
    final r = remote(404, jsonEncode({'error': 'not_found'}));
    expect(await r.get('id', 't'), isNull);
  });
}
