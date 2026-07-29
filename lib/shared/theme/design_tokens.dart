// Design tokens (U1) — one source of truth for spacing, radius, elevation and
// role gradients, so every premium surface is shaped and spaced identically.
//
// Premium here means restraint: an 8-based spacing rhythm, generous radii, and
// soft low-opacity shadows (not hard Material elevation). The clinical
// classification palette lives in app_theme.dart and is never touched here.
//
// See docs/PREMIUM_UI_ROADMAP.md — U1.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/auth/app_role.dart';

/// 8-based spacing scale. Use these instead of ad-hoc EdgeInsets numbers.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets page = EdgeInsets.all(lg);
}

/// Corner radii — generous and consistent.
abstract final class AppRadius {
  static const Radius sm = Radius.circular(10);
  static const Radius md = Radius.circular(14);
  static const Radius lg = Radius.circular(20);
  static const Radius xl = Radius.circular(28);
  static const Radius pill = Radius.circular(999);

  static const BorderRadius allSm = BorderRadius.all(sm);
  static const BorderRadius allMd = BorderRadius.all(md);
  static const BorderRadius allLg = BorderRadius.all(lg);
  static const BorderRadius allXl = BorderRadius.all(xl);
  static const BorderRadius allPill = BorderRadius.all(pill);
}

/// Soft, layered shadows — quiet depth rather than heavy Material elevation.
abstract final class AppShadows {
  /// A resting card: barely-there lift.
  static List<BoxShadow> soft(Brightness b) => [
        BoxShadow(
          color:
              Colors.black.withValues(alpha: b == Brightness.dark ? 0.4 : 0.05),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  /// A raised / hero element: a touch more presence.
  static List<BoxShadow> lifted(Brightness b) => [
        BoxShadow(
          color:
              Colors.black.withValues(alpha: b == Brightness.dark ? 0.5 : 0.09),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}

/// Role-tinted hero gradients. Each role's primary, softened into a diagonal
/// wash — tailored per role, still one brand. Kept subtle so text stays legible.
LinearGradient roleGradient(AppRole role, Brightness brightness) {
  final base = _roleSeed(role);
  if (brightness == Brightness.dark) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(base, Colors.black, 0.45)!,
        Color.lerp(base, Colors.black, 0.7)!,
      ],
    );
  }
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [base, Color.lerp(base, Colors.black, 0.22)!],
  );
}

/// The primary seed per role (mirrors AppTheme's palette).
Color _roleSeed(AppRole role) => switch (role) {
      AppRole.aww => const Color(0xFF00695C),
      AppRole.supervisor => const Color(0xFF2E7D32),
      AppRole.doctor => const Color(0xFF1565C0),
      AppRole.parent => const Color(0xFFE68A00),
      AppRole.admin => const Color(0xFF4B5570),
    };
