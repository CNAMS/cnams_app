// Auth tests: the mock API's OTP/Google flows, and the controller persisting a
// session and setting the active role.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/auth/auth_api.dart';
import 'package:cgms_app/core/auth/auth_controller.dart';
import 'package:cgms_app/core/auth/auth_models.dart';
import 'package:cgms_app/core/auth/secure_store.dart';
import 'package:cgms_app/core/providers.dart';

class InMemoryStore implements SecureStore {
  final Map<String, String> map = {};
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
}

void main() {
  group('MockAuthApi', () {
    final api = MockAuthApi();

    test('verifyOtp accepts the dev code and rejects others', () async {
      final challenge = await api.requestOtp(OtpChannel.phone, '9876543210');
      final session = await api.verifyOtp(
        challenge,
        MockAuthApi.devCode,
        AppRole.parent,
      );
      expect(session.role, AppRole.parent);
      expect(session.method, AuthMethod.phoneOtp);

      expect(
        () => api.verifyOtp(challenge, '000000', AppRole.parent),
        throwsA(isA<AuthException>()),
      );
    });

    test('requestOtp rejects an empty destination', () {
      expect(
        () => api.requestOtp(OtpChannel.email, '   '),
        throwsA(isA<AuthException>()),
      );
    });

    test('Google sign-in returns a session for the role', () async {
      final s = await api.signInWithGoogle(AppRole.doctor);
      expect(s.role, AppRole.doctor);
      expect(s.method, AuthMethod.google);
    });

    test('email+password creates on first use, then verifies', () async {
      final api = MockAuthApi();
      final created = await api.signInWithPassword(
        'aww@example.com',
        'secret123',
        AppRole.aww,
      );
      expect(created.method, AuthMethod.password);

      // Correct password signs into the same account.
      final again = await api.signInWithPassword(
        'aww@example.com',
        'secret123',
        AppRole.aww,
      );
      expect(again.userId, created.userId);

      // Wrong password is rejected.
      expect(
        () => api.signInWithPassword('aww@example.com', 'nope', AppRole.aww),
        throwsA(isA<AuthException>()),
      );
    });

    test('email+password rejects bad email or short password', () {
      final api = MockAuthApi();
      expect(
        () => api.signInWithPassword('notanemail', 'secret123', AppRole.aww),
        throwsA(isA<AuthException>()),
      );
      expect(
        () => api.signInWithPassword('a@b.com', '123', AppRole.aww),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('AuthController', () {
    late InMemoryStore store;
    late ProviderContainer container;

    setUp(() {
      store = InMemoryStore();
      container = ProviderContainer(
        overrides: [secureStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
    });

    test('starts signed out', () async {
      final session = await container.read(authControllerProvider.future);
      expect(session, isNull);
    });

    test('Google sign-in persists the session and sets the role', () async {
      await container.read(authControllerProvider.future); // build
      await container
          .read(authControllerProvider.notifier)
          .signInWithGoogle(AppRole.supervisor);

      final session = container.read(authControllerProvider).value;
      expect(session, isNotNull);
      expect(session!.role, AppRole.supervisor);
      expect(container.read(currentRoleProvider), AppRole.supervisor);
      expect(store.map.containsKey('auth_session'), isTrue);
    });

    test('a persisted session is restored on build and sets the role',
        () async {
      const session = AuthSession(
        userId: 'u1',
        role: AppRole.admin,
        method: AuthMethod.google,
        token: 't',
      );
      store.map['auth_session'] = session.encode();

      final restored = await container.read(authControllerProvider.future);
      expect(restored!.role, AppRole.admin);
      expect(container.read(currentRoleProvider), AppRole.admin);
    });

    test('sign-out clears the session and resets unlock + role (security)',
        () async {
      await container.read(authControllerProvider.future);
      final c = container.read(authControllerProvider.notifier);
      await c.signInWithGoogle(AppRole.doctor);
      // Simulate the session having been PIN-unlocked.
      container.read(sessionUnlockedProvider.notifier).state = true;

      await c.signOut();

      expect(container.read(authControllerProvider).value, isNull);
      expect(store.map.containsKey('auth_session'), isFalse);
      // A different user must not inherit the unlocked state or the role.
      expect(container.read(sessionUnlockedProvider), isFalse);
      expect(container.read(currentRoleProvider), AppRole.aww);
    });
  });
}
