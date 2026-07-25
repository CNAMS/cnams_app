// A tiny key/value abstraction over secure storage.
//
// The interface lets the PIN and token logic be unit-tested with an in-memory
// fake, while the app uses the platform keystore/keychain via
// flutter_secure_storage.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P4.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Platform-backed secure storage (iOS Keychain / Android Keystore).
class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
