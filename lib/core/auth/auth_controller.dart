// Auth session controller. Loads a persisted session on start, runs sign-in via
// the (mock) AuthApi, persists the session in secure storage, and sets the
// active role so the theme and navigation follow.
//
// See docs/ANKUR_EXPERIENCE_ROADMAP.md — EX2.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/auth/auth_api.dart';
import 'package:cgms_app/core/auth/auth_models.dart';
import 'package:cgms_app/core/providers.dart';

const String _sessionKey = 'auth_session';

/// The auth backend. Mock until the identity service exists (EX2).
final authApiProvider = Provider<AuthApi>((ref) => MockAuthApi());

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final raw = await ref.read(secureStoreProvider).read(_sessionKey);
    final session = raw == null ? null : AuthSession.decode(raw);
    if (session != null) {
      ref.read(currentRoleProvider.notifier).state = session.role;
    }
    return session;
  }

  AuthApi get _api => ref.read(authApiProvider);

  /// Request an OTP; returns the challenge to hand to [verifyOtp]. Does not
  /// change session state.
  Future<OtpChallenge> requestOtp(OtpChannel channel, String destination) =>
      _api.requestOtp(channel, destination);

  Future<void> verifyOtp(OtpChallenge challenge, String code, AppRole role) =>
      _complete(() => _api.verifyOtp(challenge, code, role));

  Future<void> signInWithGoogle(AppRole role) =>
      _complete(() => _api.signInWithGoogle(role));

  Future<void> _complete(Future<AuthSession> Function() run) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await run();
      await ref.read(secureStoreProvider).write(_sessionKey, session.encode());
      ref.read(currentRoleProvider.notifier).state = session.role;
      return session;
    });
  }

  Future<void> signOut() async {
    await ref.read(secureStoreProvider).delete(_sessionKey);
    state = const AsyncData(null);
  }
}
