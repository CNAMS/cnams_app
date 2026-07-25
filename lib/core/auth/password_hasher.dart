// Password hashing for the (mock) email+password auth. PBKDF2-HMAC-SHA256 with a
// per-password random salt — never store or compare a raw password.
//
// Stored form is "base64(salt):base64(hash)". A real backend would do this
// server-side; keeping the primitive here means the mock behaves correctly and
// the same code can move server-side later.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const int _iterations = 100000;

String hashPassword(String password, {Random? random}) {
  final rng = random ?? Random.secure();
  final salt =
      Uint8List.fromList([for (var i = 0; i < 16; i++) rng.nextInt(256)]);
  final hash = _pbkdf2(password, salt, _iterations);
  return '${base64Encode(salt)}:${base64Encode(hash)}';
}

bool verifyPassword(String password, String stored) {
  final parts = stored.split(':');
  if (parts.length != 2) return false;
  final salt = base64Decode(parts[0]);
  final expected = base64Decode(parts[1]);
  final derived = _pbkdf2(password, salt, _iterations);
  return _constantTimeEquals(derived, expected);
}

Uint8List _pbkdf2(String password, List<int> salt, int iterations) {
  final hmac = Hmac(sha256, utf8.encode(password));
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
