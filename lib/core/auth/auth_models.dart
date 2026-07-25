// Auth value types. Pure Dart.
//
// See docs/ANKUR_EXPERIENCE_ROADMAP.md — EX2.

import 'dart:convert';

import 'package:cgms_app/core/auth/app_role.dart';

enum AuthMethod { google, phoneOtp, emailOtp, password, pin }

enum OtpChannel { phone, email }

/// A pending OTP verification — returned by [AuthApi.requestOtp], passed back to
/// [AuthApi.verifyOtp].
class OtpChallenge {
  const OtpChallenge({
    required this.id,
    required this.channel,
    required this.destination,
  });

  final String id;
  final OtpChannel channel;
  final String destination;
}

/// A signed-in session.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.role,
    required this.method,
    required this.token,
    this.displayName,
  });

  final String userId;
  final AppRole role;
  final AuthMethod method;
  final String token;
  final String? displayName;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'role': role.id,
        'method': method.name,
        'token': token,
        'displayName': displayName,
      };

  static AuthSession fromJson(Map<String, dynamic> j) => AuthSession(
        userId: j['userId'] as String,
        role: AppRole.fromId(j['role'] as String),
        method: AuthMethod.values.firstWhere((m) => m.name == j['method']),
        token: j['token'] as String,
        displayName: j['displayName'] as String?,
      );

  String encode() => jsonEncode(toJson());

  static AuthSession decode(String s) =>
      fromJson(jsonDecode(s) as Map<String, dynamic>);
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => 'AuthException: $message';
}
