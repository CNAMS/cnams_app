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

/// Outcome of a PIN check.
class PinVerifyResult {
  const PinVerifyResult(this.ok, {this.lockedFor});

  final bool ok;

  /// Non-null when the PIN is locked out; how long remains before another try.
  final Duration? lockedFor;

  bool get isLocked => lockedFor != null;
}

class PinAuth {
  PinAuth(
    this._store, {
    this.iterations = 100000,
    Random? random,
    DateTime Function() now = DateTime.now,
  })  : _random = random ?? Random.secure(),
        _now = now;

  static const _saltKey = 'pin_salt';
  static const _hashKey = 'pin_hash';
  static const _attemptsKey = 'pin_attempts';
  static const _lockUntilKey = 'pin_lock_until';

  /// Wrong tries allowed before a lockout starts.
  static const int maxAttempts = 5;
  static const Duration _baseLock = Duration(seconds: 30);
  static const Duration _maxLock = Duration(minutes: 15);

  final SecureStore _store;
  final int iterations;
  final Random _random;
  final DateTime Function() _now;

  Future<bool> isPinSet() async => await _store.read(_hashKey) != null;

  /// Set (or replace) the PIN and clear any lockout.
  Future<void> setPin(String pin) async {
    final salt = _randomBytes(16);
    final hash = _pbkdf2(pin, salt, iterations);
    await _store.write(_saltKey, base64Encode(salt));
    await _store.write(_hashKey, base64Encode(hash));
    await _resetAttempts();
  }

  /// Remaining lockout, or null if not locked.
  Future<Duration?> remainingLockout() async {
    final raw = await _store.read(_lockUntilKey);
    if (raw == null) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(int.parse(raw));
    final remaining = until.difference(_now());
    return remaining > Duration.zero ? remaining : null;
  }

  /// Check [pin]. While locked out, returns a locked result without checking.
  /// Repeated wrong entries trigger a growing lockout; a correct entry clears it.
  Future<PinVerifyResult> verify(String pin) async {
    final locked = await remainingLockout();
    if (locked != null) return PinVerifyResult(false, lockedFor: locked);

    final saltB64 = await _store.read(_saltKey);
    final hashB64 = await _store.read(_hashKey);
    if (saltB64 == null || hashB64 == null) return const PinVerifyResult(false);

    final derived = _pbkdf2(pin, base64Decode(saltB64), iterations);
    final ok = _constantTimeEquals(derived, base64Decode(hashB64));
    if (ok) {
      await _resetAttempts();
      return const PinVerifyResult(true);
    }

    // Wrong: count it, and lock out once past the threshold.
    final attempts =
        (int.tryParse(await _store.read(_attemptsKey) ?? '') ?? 0) + 1;
    await _store.write(_attemptsKey, '$attempts');
    if (attempts >= maxAttempts) {
      final over = attempts - maxAttempts;
      var ms = _baseLock.inMilliseconds * (1 << over.clamp(0, 20));
      ms = ms.clamp(0, _maxLock.inMilliseconds);
      final until = _now().add(Duration(milliseconds: ms));
      await _store.write(_lockUntilKey, '${until.millisecondsSinceEpoch}');
      return PinVerifyResult(false, lockedFor: Duration(milliseconds: ms));
    }
    return const PinVerifyResult(false);
  }

  Future<void> clear() async {
    await _store.delete(_saltKey);
    await _store.delete(_hashKey);
    await _resetAttempts();
  }

  Future<void> _resetAttempts() async {
    await _store.delete(_attemptsKey);
    await _store.delete(_lockUntilKey);
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
