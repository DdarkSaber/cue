import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';

/// Crockford base32 without I, L, O, U, so codes survive being read aloud.
const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// A new sync code: 160 random bits as 32 characters in groups of four.
String newSyncCode([Random? random]) {
  final r = random ?? Random.secure();
  final chars = List.generate(32, (_) => _alphabet[r.nextInt(32)]).join();
  return [for (var i = 0; i < 32; i += 4) chars.substring(i, i + 4)].join('-');
}

/// Canonical form: upper case, separators and spaces dropped, look-alike
/// letters mapped (O to 0, I and L to 1). Null when it is not a code.
String? normalizeSyncCode(String input) {
  final s = input
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\-_.]'), '')
      .replaceAll('O', '0')
      .replaceAll(RegExp('[IL]'), '1');
  if (s.length != 32) return null;
  for (final c in s.split('')) {
    if (!_alphabet.contains(c)) return null;
  }
  return s;
}

/// Everything derived from a code. The Worker only ever sees [id] and
/// [token]; the [key] never leaves the device.
class SyncKeys {
  const SyncKeys(this.id, this.token, this.key);
  final String id;
  final String token;
  final SecretKey key;
}

Future<List<int>> _hkdf(String code, String info, int length) async {
  final out = await Hkdf(hmac: Hmac.sha256(), outputLength: length).deriveKey(
    secretKey: SecretKey(utf8.encode(code)),
    nonce: utf8.encode('cue-sync-v1'),
    info: utf8.encode(info),
  );
  return out.extractBytes();
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

/// The code is 160 random bits, so a fast KDF is enough: nothing to
/// brute-force that a slow one would protect.
Future<SyncKeys> deriveSyncKeys(String normalizedCode) async {
  final id = _hex(await _hkdf(normalizedCode, 'id', 16));
  final token = base64Url
      .encode(await _hkdf(normalizedCode, 'token', 32))
      .replaceAll('=', '');
  final key = SecretKey(await _hkdf(normalizedCode, 'key', 32));
  return SyncKeys(id, token, key);
}

final _aes = AesGcm.with256bits();
const _formatVersion = 1;

/// gzip, then AES-256-GCM with a fresh nonce. Layout: version byte,
/// 12-byte nonce, ciphertext, 16-byte tag; base64 for transport.
Future<String> sealBlob(String plaintext, SecretKey key) async {
  final packed = const GZipEncoder().encode(utf8.encode(plaintext));
  final box = await _aes.encrypt(
    packed,
    secretKey: key,
    nonce: _aes.newNonce(),
    aad: const [_formatVersion],
  );
  final out = BytesBuilder()
    ..addByte(_formatVersion)
    ..add(box.nonce)
    ..add(box.cipherText)
    ..add(box.mac.bytes);
  return base64.encode(out.toBytes());
}

/// Thrown when a blob cannot be opened (wrong code or tampered data).
class SyncDecryptFailed implements Exception {
  const SyncDecryptFailed();
}

Future<String> openBlob(String blob, SecretKey key) async {
  try {
    final bytes = base64.decode(blob);
    if (bytes.isEmpty ||
        bytes[0] != _formatVersion ||
        bytes.length < 1 + 12 + 16) {
      throw const SyncDecryptFailed();
    }
    final nonce = bytes.sublist(1, 13);
    final mac = Mac(bytes.sublist(bytes.length - 16));
    final cipher = bytes.sublist(13, bytes.length - 16);
    final packed = await _aes.decrypt(
      SecretBox(cipher, nonce: nonce, mac: mac),
      secretKey: key,
      aad: const [_formatVersion],
    );
    final raw = const GZipDecoder().decodeBytes(packed);
    if (raw.length > 100 * 1024 * 1024) throw const SyncDecryptFailed();
    return utf8.decode(raw);
  } on SyncDecryptFailed {
    rethrow;
  } on Object {
    throw const SyncDecryptFailed();
  }
}
