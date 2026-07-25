// PIN auth tests against an in-memory secure store. Low iteration count keeps
// the test fast; production uses many more.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/auth/pin_auth.dart';
import 'package:cgms_app/core/auth/secure_store.dart';

class InMemoryStore implements SecureStore {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;

  @override
  Future<void> delete(String key) async => _map.remove(key);

  Map<String, String> get raw => _map;
}

void main() {
  late InMemoryStore store;
  late PinAuth auth;

  setUp(() {
    store = InMemoryStore();
    auth = PinAuth(store, iterations: 1000, random: Random(7));
  });

  test('no PIN set initially', () async {
    expect(await auth.isPinSet(), isFalse);
    expect(await auth.verify('1234'), isFalse);
  });

  test('accepts the correct PIN and rejects a wrong one', () async {
    await auth.setPin('2468');
    expect(await auth.isPinSet(), isTrue);
    expect(await auth.verify('2468'), isTrue);
    expect(await auth.verify('1357'), isFalse);
  });

  test('the raw PIN is never stored', () async {
    await auth.setPin('9999');
    expect(store.raw.values, isNot(contains('9999')));
    expect(store.raw.containsKey('pin_hash'), isTrue);
    expect(store.raw.containsKey('pin_salt'), isTrue);
  });

  test('a fresh salt makes the stored hash differ for the same PIN', () async {
    await auth.setPin('1111');
    final firstHash = store.raw['pin_hash'];
    await PinAuth(store, iterations: 1000, random: Random(42)).setPin('1111');
    expect(store.raw['pin_hash'], isNot(firstHash));
  });

  test('clear removes the PIN', () async {
    await auth.setPin('0000');
    await auth.clear();
    expect(await auth.isPinSet(), isFalse);
  });
}
