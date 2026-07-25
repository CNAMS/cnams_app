// PIN unlock (FR-APP-16).
//
// The PIN is never stored. We keep a random salt and a PBKDF2-HMAC-SHA256
// derivation of the PIN in secure storage, and verify by re-deriving and
// comparing in constant time. PBKDF2 with many iterations slows brute force of
// a low-entropy PIN; the salt makes each device's hash unique.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P4.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:cgms_app/core/auth/secure_store.dart';

class PinAuth {
  PinAuth(
    this._store, {
    this.iterations = 100000,
    Random? random,
  }) : _random = random ?? Random.secure();

  static const _saltKey = 'pin_salt';
  static const _hashKey = 'pin_hash';

  final SecureStore _store;
  final int iterations;
  final Random _random;

  Future<bool> isPinSet() async => await _store.read(_hashKey) != null;

  /// Set (or replace) the PIN.
  Future<void> setPin(String pin) async {
    final salt = _randomBytes(16);
    final hash = _pbkdf2(pin, salt, iterations);
    await _store.write(_saltKey, base64Encode(salt));
    await _store.write(_hashKey, base64Encode(hash));
  }

  /// True if [pin] matches the stored derivation.
  Future<bool> verify(String pin) async {
    final saltB64 = await _store.read(_saltKey);
    final hashB64 = await _store.read(_hashKey);
    if (saltB64 == null || hashB64 == null) return false;

    final derived = _pbkdf2(pin, base64Decode(saltB64), iterations);
    return _constantTimeEquals(derived, base64Decode(hashB64));
  }

  Future<void> clear() async {
    await _store.delete(_saltKey);
    await _store.delete(_hashKey);
  }

  Uint8List _randomBytes(int n) =>
      Uint8List.fromList([for (var i = 0; i < n; i++) _random.nextInt(256)]);
}

/// PBKDF2-HMAC-SHA256 producing a single 32-byte block (dkLen == hLen).
Uint8List _pbkdf2(String password, List<int> salt, int iterations) {
  final hmac = Hmac(sha256, utf8.encode(password));
  // INT_32_BE(1) appended to the salt for the first (and only) block.
  var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final result = Uint8List.fromList(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= u[j];
    }
  }
  return result;
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
