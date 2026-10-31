import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// PKCE verifier: 64 characters from the unreserved set.
String pkceVerifier([Random? random]) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  final r = random ?? Random.secure();
  return List.generate(64, (_) => chars[r.nextInt(chars.length)]).join();
}

/// S256 challenge for a verifier (base64url, no padding).
String pkceS256(String verifier) => base64Url
    .encode(sha256.convert(ascii.encode(verifier)).bytes)
    .replaceAll('=', '');

/// Where the provider sends the person back: the app scheme on mobile,
/// the auth page on the web origin.
String redirectUriFor(String provider) =>
    kIsWeb ? '${Uri.base.origin}/auth.html' : 'cue://oauth/$provider';

/// Opens the provider's own sign-in page in the system browser (never a
/// password field in Cue) and returns the authorization code.
///
/// MAL echoes the `state` Cue sent; a missing or different one means the
/// redirect did not come from this sign-in, so the code is refused.
Future<String?> authorize(Uri url, String provider, {String? state}) async {
  final result = await FlutterWebAuth2.authenticate(
    url: url.toString(),
    callbackUrlScheme: kIsWeb ? 'https' : 'cue',
  );
  final back = Uri.parse(result);
  if (back.queryParameters['error'] != null) return null;
  if (state != null && back.queryParameters['state'] != state) return null;
  return back.queryParameters['code'];
}

/// MAL's authorize URL. MAL documents only the plain PKCE method.
Uri authorizeUrl(
  String provider, {
  required String clientId,
  required String redirectUri,
  required String verifier,
  required String state,
}) => Uri.https('myanimelist.net', '/v1/oauth2/authorize', {
  'response_type': 'code',
  'client_id': clientId,
  'redirect_uri': redirectUri,
  'code_challenge': verifier,
  'code_challenge_method': 'plain',
  'state': state,
});
