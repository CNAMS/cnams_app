import 'package:flutter/material.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/zscore/classification.dart';

/// Ankur's theme — one brand, tuned per role.
///
/// The AWW's phone is used outdoors in a courtyard, often in bright sun,
/// sometimes by a worker with colour-vision deficiency, and the parent card may
/// be photocopied in greyscale. So: high contrast, a large base font, generous
/// touch targets, and classification colours that are always paired with a word
/// and an icon — never colour alone.
///
/// Each role gets a light and dark variant that swaps only the primary/surface
/// (see [_RolePalette] and docs/ANKUR_EXPERIENCE_ROADMAP.md §2.1). The
/// classification palette in [styleFor] never changes — it's clinical.
class AppTheme {
  const AppTheme._();

  /// Minimum interactive size — comfortably above the 48 dp floor.
  static const double minTouchTarget = 48;

  /// Base body text size; system text scaling is honoured on top of this.
  static const double baseFontSize = 16;

  /// The AWW field theme (unchanged) — kept as the default entry point.
  static ThemeData light() => forRole(AppRole.aww, Brightness.light);

  /// The themed [ThemeData] for a role and brightness.
  static ThemeData forRole(AppRole role, Brightness brightness) {
    final palette = _RolePalette.of(role);
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.seed,
      brightness: brightness,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    final surface =
        brightness == Brightness.light ? palette.lightSurface : null;

    return base.copyWith(
      scaffoldBackgroundColor: surface,
      visualDensity: VisualDensity.comfortable,
      // One quiet, consistent page transition everywhere (EX5 motion).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          textStyle: const TextStyle(
            fontSize: baseFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// The visual band for a classification. Colour is only ever half the signal —
  /// callers must render [ClassificationStyle.icon] and a text label too.
  static ClassificationStyle styleFor(GrowthClass c) {
    switch (c) {
      case GrowthClass.normal:
        return const ClassificationStyle(
          color: Color(0xFF2E7D32), // green
          onColor: Colors.white,
          icon: Icons.check_circle,
        );
      case GrowthClass.overweight:
        return const ClassificationStyle(
          color:
              Color(0xFF1565C0), // blue — distinct from the malnutrition scale
          onColor: Colors.white,
          icon: Icons.info,
        );
      case GrowthClass.mam:
        return const ClassificationStyle(
          color: Color(0xFFF9A825), // amber
          onColor: Color(0xFF1A1A1A),
          icon: Icons.warning,
        );
      case GrowthClass.sam:
        return const ClassificationStyle(
          color: Color(0xFFC62828), // red
          onColor: Colors.white,
          icon: Icons.error,
        );
      case GrowthClass.indeterminate:
        return const ClassificationStyle(
          color: Color(0xFF616161), // grey — we are not guessing
          onColor: Colors.white,
          icon: Icons.help,
        );
    }
  }
}

/// Colour + foreground + icon for a classification band. Bundled together so a
/// caller can't accidentally use the colour without the icon.
class ClassificationStyle {
  const ClassificationStyle({
    required this.color,
    required this.onColor,
    required this.icon,
  });

  final Color color;
  final Color onColor;
  final IconData icon;
}

/// Per-role seed + light-surface tint. One brand, five tuned skins; only the
/// primary and surface temperature change (roadmap §2.1). The AWW palette is the
/// original field theme.
class _RolePalette {
  const _RolePalette(this.seed, this.lightSurface);

  final Color seed;
  final Color lightSurface;

  static _RolePalette of(AppRole role) {
    switch (role) {
      case AppRole.aww:
        return const _RolePalette(Color(0xFF00695C), Color(0xFFFBF8F1));
      case AppRole.supervisor:
        return const _RolePalette(Color(0xFF2E7D32), Color(0xFFF6F8F3));
      case AppRole.doctor:
        return const _RolePalette(Color(0xFF1565C0), Color(0xFFF5F8FC));
      case AppRole.parent:
        return const _RolePalette(Color(0xFFE68A00), Color(0xFFFDF7EE));
      case AppRole.admin:
        // A light "console" — slate/indigo on cool grey, deliberately not dark.
        return const _RolePalette(Color(0xFF4B5570), Color(0xFFEEF1F5));
    }
  }
}
