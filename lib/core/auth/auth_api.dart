// The auth transport contract and a mock implementation.
//
// The real server isn't built yet, so the app runs against [MockAuthApi] — the
// same pattern as SyncApi. When the identity service exists, an HTTP
// implementation slots in behind this interface without touching the screens.
//
// The mock accepts a fixed dev OTP code and trusts the role picked at sign-in
// (a real backend would verify OTP delivery and enforce role approval).
//
// See docs/ANKUR_EXPERIENCE_ROADMAP.md — EX2.

import 'package:uuid/uuid.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/auth/auth_models.dart';
import 'package:cgms_app/core/auth/password_hasher.dart';

abstract class AuthApi {
  /// Ask the backend to send a code to [destination] over [channel].
  Future<OtpChallenge> requestOtp(OtpChannel channel, String destination);

  /// Verify [code] against a [challenge]; returns a session for [role].
  Future<AuthSession> verifyOtp(
    OtpChallenge challenge,
    String code,
    AppRole role,
  );

  /// Complete a Google sign-in for [role].
  Future<AuthSession> signInWithGoogle(AppRole role);

  /// Sign in with email + password, creating the account on first use.
  Future<AuthSession> signInWithPassword(
    String email,
    String password,
    AppRole role,
  );
}

class MockAuthApi implements AuthApi {
  MockAuthApi({Uuid uuid = const Uuid()}) : _uuid = uuid;

  final Uuid _uuid;

  /// The code the mock accepts (a real backend sends a random code by SMS/email).
  static const String devCode = '123456';

  @override
  Future<OtpChallenge> requestOtp(
    OtpChannel channel,
    String destination,
  ) async {
    if (destination.trim().isEmpty) {
      throw const AuthException('missing destination');
    }
    // A real backend would dispatch the code here.
    return OtpChallenge(
      id: _uuid.v4(),
      channel: channel,
      destination: destination.trim(),
    );
  }

  @override
  Future<AuthSession> verifyOtp(
    OtpChallenge challenge,
    String code,
    AppRole role,
  ) async {
    if (code.trim() != devCode) {
      throw const AuthException('incorrect code');
    }
    return AuthSession(
      userId: _uuid.v4(),
      role: role,
      method: challenge.channel == OtpChannel.phone
          ? AuthMethod.phoneOtp
          : AuthMethod.emailOtp,
      token: _uuid.v4(),
      displayName: challenge.destination,
    );
  }

  @override
  Future<AuthSession> signInWithGoogle(AppRole role) async {
    return AuthSession(
      userId: _uuid.v4(),
      role: role,
      method: AuthMethod.google,
      token: _uuid.v4(),
      displayName: 'Google user',
    );
  }

  // In-memory accounts for the mock: email -> (hashed password, userId, role).
  final Map<String, ({String hash, String userId, AppRole role})> _accounts =
      {};

  @override
  Future<AuthSession> signInWithPassword(
    String email,
    String password,
    AppRole role,
  ) async {
    final key = email.trim().toLowerCase();
    if (key.isEmpty || !key.contains('@')) {
      throw const AuthException('enter a valid email');
    }
    if (password.length < 6) {
      throw const AuthException('password too short');
    }

    final existing = _accounts[key];
    if (existing == null) {
      // First use of this email: create the account.
      final account = (
        hash: hashPassword(password),
        userId: _uuid.v4(),
        role: role,
      );
      _accounts[key] = account;
      return _sessionFor(account, key);
    }
    if (!verifyPassword(password, existing.hash)) {
      throw const AuthException('incorrect password');
    }
    return _sessionFor(existing, key);
  }

  AuthSession _sessionFor(
    ({String hash, String userId, AppRole role}) account,
    String email,
  ) {
    return AuthSession(
      userId: account.userId,
      role: account.role,
      method: AuthMethod.password,
      token: _uuid.v4(),
      displayName: email,
    );
  }
}
