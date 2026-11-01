import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where a provider's read-only tokens are kept after sign-in: platform
/// secure storage (Keystore, Keychain; WebCrypto-wrapped storage on the web).
/// Never synced, never sent anywhere but that provider through the Worker.
abstract class TokenStore {
  Future<String?> read(String provider);
  Future<void> write(String provider, String token);
  Future<void> delete(String provider);

  /// The account name shown next to "Signed in" (not a secret).
  Future<String?> readName(String provider);
  Future<void> writeName(String provider, String name);

  /// The refresh token. On the web it lives only for the browser tab
  /// session, because a browser has no hardware-backed store.
  Future<String?> readRefresh(String provider);
  Future<void> writeRefresh(String provider, String? token);

  Future<DateTime?> readExpiry(String provider);
  Future<void> writeExpiry(String provider, DateTime? at);
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore();
  static const _storage = FlutterSecureStorage();
  static const _session = FlutterSecureStorage(
    webOptions: WebOptions(useSessionStorage: true),
  );
  String _key(String p) => 'cue_oauth_$p';

  @override
  Future<String?> read(String provider) => _storage.read(key: _key(provider));
  @override
  Future<void> write(String provider, String token) =>
      _storage.write(key: _key(provider), value: token);
  @override
  Future<void> delete(String provider) async {
    for (final k in ['', '_name', '_exp']) {
      await _storage.delete(key: '${_key(provider)}$k');
    }
    await _session.delete(key: '${_key(provider)}_refresh');
  }

  @override
  Future<String?> readName(String provider) =>
      _storage.read(key: '${_key(provider)}_name');
  @override
  Future<void> writeName(String provider, String name) =>
      _storage.write(key: '${_key(provider)}_name', value: name);

  @override
  Future<String?> readRefresh(String provider) =>
      _session.read(key: '${_key(provider)}_refresh');
  @override
  Future<void> writeRefresh(String provider, String? token) => token == null
      ? _session.delete(key: '${_key(provider)}_refresh')
      : _session.write(key: '${_key(provider)}_refresh', value: token);

  @override
  Future<DateTime?> readExpiry(String provider) async {
    final v = await _storage.read(key: '${_key(provider)}_exp');
    return v == null ? null : DateTime.tryParse(v);
  }

  @override
  Future<void> writeExpiry(String provider, DateTime? at) => at == null
      ? _storage.delete(key: '${_key(provider)}_exp')
      : _storage.write(
          key: '${_key(provider)}_exp',
          value: at.toIso8601String(),
        );
}

class MemoryTokenStore implements TokenStore {
  final _tokens = <String, String>{};
  final _names = <String, String>{};
  final _refresh = <String, String>{};
  final _expiry = <String, DateTime>{};

  @override
  Future<String?> read(String provider) async => _tokens[provider];
  @override
  Future<void> write(String provider, String token) async =>
      _tokens[provider] = token;
  @override
  Future<void> delete(String provider) async {
    _tokens.remove(provider);
    _names.remove(provider);
    _refresh.remove(provider);
    _expiry.remove(provider);
  }

  @override
  Future<String?> readName(String provider) async => _names[provider];
  @override
  Future<void> writeName(String provider, String name) async =>
      _names[provider] = name;

  @override
  Future<String?> readRefresh(String provider) async => _refresh[provider];
  @override
  Future<void> writeRefresh(String provider, String? token) async =>
      token == null ? _refresh.remove(provider) : _refresh[provider] = token;

  @override
  Future<DateTime?> readExpiry(String provider) async => _expiry[provider];
  @override
  Future<void> writeExpiry(String provider, DateTime? at) async =>
      at == null ? _expiry.remove(provider) : _expiry[provider] = at;
}
