import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where a provider's read-only access token is kept after sign-in: platform
/// secure storage (Keystore, Keychain; WebCrypto-wrapped storage on the web).
/// Never synced, never sent anywhere but that provider through the Worker.
abstract class TokenStore {
  Future<String?> read(String provider);
  Future<void> write(String provider, String token);
  Future<void> delete(String provider);
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore();
  static const _storage = FlutterSecureStorage();
  String _key(String p) => 'cue_oauth_$p';

  @override
  Future<String?> read(String provider) => _storage.read(key: _key(provider));
  @override
  Future<void> write(String provider, String token) =>
      _storage.write(key: _key(provider), value: token);
  @override
  Future<void> delete(String provider) => _storage.delete(key: _key(provider));
}

class MemoryTokenStore implements TokenStore {
  final _tokens = <String, String>{};
  @override
  Future<String?> read(String provider) async => _tokens[provider];
  @override
  Future<void> write(String provider, String token) async =>
      _tokens[provider] = token;
  @override
  Future<void> delete(String provider) async => _tokens.remove(provider);
}
