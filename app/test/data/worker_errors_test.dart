import 'dart:convert';

import 'package:cue/data/catalog_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  HttpCatalogGateway gateway(int status, String body) => HttpCatalogGateway(
    'https://worker.test',
    client: MockClient((_) async => http.Response(body, status)),
  );

  Future<String> code(Future<Object?> Function() call) async {
    try {
      await call();
    } on CatalogUnavailable catch (e) {
      return e.code;
    }
    fail('expected CatalogUnavailable');
  }

  test('a 401 token_expired body is reported as token_expired', () async {
    final g = gateway(401, jsonEncode({'error': 'token_expired'}));
    expect(await code(() => g.listSignedIn('mal', 't')), 'token_expired');
    expect(await code(() => g.refreshTokens('mal', 'rt')), 'token_expired');
  });

  test('a 401 without a body is http_401, not a broken answer', () async {
    final g = gateway(401, '');
    expect(await code(() => g.refreshTokens('mal', 'rt')), 'http_401');
    expect(await code(() => g.listSignedIn('mal', 't')), 'http_401');
  });

  test('outages and rate limits keep their codes', () async {
    expect(
      await code(
        () => gateway(
          502,
          jsonEncode({'error': 'upstream_error'}),
        ).listSignedIn('mal', 't'),
      ),
      'upstream_error',
    );
    expect(
      await code(
        () => gateway(
          429,
          jsonEncode({'error': 'rate_limited'}),
        ).listSignedIn('mal', 't'),
      ),
      'rate_limited',
    );
    expect(await code(() => gateway(503, '<html>').oauthConfig()), 'http_503');
  });

  test('a 200 that is not JSON is a broken answer', () async {
    expect(
      await code(() => gateway(200, '<html>').listSignedIn('mal', 't')),
      'bad_response',
    );
  });
}
