import 'package:flutter/material.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/shared/theme/design_tokens.dart';
import 'package:cgms_app/shared/theme/role_palette.dart';

/// Ankur's theme — one brand, tuned per role.
///
/// The AWW's phone is used outdoors in a courtyard, often in bright sun,
/// sometimes by a worker with colour-vision deficiency, and the parent card may
/// be photocopied in greyscale. So: high contrast, a large base font, generous
/// touch targets, and classification colours that are always paired with a word
/// and an icon — never colour alone.
///
/// Each role gets a light and dark variant that swaps only the accent and the
/// page tint (see [RolePalette] and docs/ANKUR_EXPERIENCE_ROADMAP.md §2.1).
/// The classification palette in [styleFor] never changes — it's clinical.
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
    final scheme = schemeFor(role, brightness);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final light = brightness == Brightness.light;

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.comfortable,
      // One quiet, consistent page transition everywhere (EX5 motion).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      // Premium geometry (U1): softer, larger radii on the common surfaces so
      // even screens not yet migrated to the premium widgets inherit the shape.
      // Borders before shadows: a card is a white sheet with a hairline.
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allLg,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: scheme.outlineVariant),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: light ? Neutrals.card : Neutrals.darkContainer,
        border: const OutlineInputBorder(borderRadius: AppRadius.allMd),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          textStyle: const TextStyle(
            fontSize: baseFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          textStyle: const TextStyle(
            fontSize: baseFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// The exact colour scheme for a role and brightness.
  ///
  /// Material's tonal roles that Ankur does not define (tertiary, inverse)
  /// still come from the accent, using the "fidelity" variant so they stay
  /// close to it; everything Ankur does define is set outright.
  static ColorScheme schemeFor(AppRole role, Brightness brightness) {
    final p = RolePalette.of(role);
    final light = brightness == Brightness.light;
    final generated = ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    return generated.copyWith(
      primary: light ? p.accent : p.darkAccent,
      onPrimary: light ? Colors.white : Neutrals.darkPage,
      primaryContainer: light ? p.accentSubtle : p.darkAccentSubtle,
      onPrimaryContainer: light ? p.onAccentSubtle : p.darkOnAccentSubtle,
      // NavigationBar's indicator and tonal buttons read secondary; keep them
      // in the role's family rather than an unrelated generated hue.
      secondary: light ? p.accentHover : p.darkAccentHover,
      onSecondary: light ? Colors.white : Neutrals.darkPage,
      secondaryContainer: light ? p.accentSubtle : p.darkAccentSubtle,
      onSecondaryContainer: light ? p.onAccentSubtle : p.darkOnAccentSubtle,
      surface: light ? p.pageTint : Neutrals.darkPage,
      onSurface: light ? Neutrals.text : Neutrals.darkText,
      onSurfaceVariant: light ? Neutrals.textMuted : Neutrals.darkTextMuted,
      surfaceContainerLowest: light ? Neutrals.card : Neutrals.darkLowest,
      surfaceContainerLow: light ? Neutrals.card : Neutrals.darkCard,
      surfaceContainer: light ? Neutrals.sunken : Neutrals.darkContainer,
      surfaceContainerHigh: light ? Neutrals.high : Neutrals.darkHigh,
      surfaceContainerHighest: light ? Neutrals.highest : Neutrals.darkHighest,
      outline: light ? Neutrals.inputBorder : Neutrals.darkInputBorder,
      outlineVariant: light ? Neutrals.line : Neutrals.darkLine,
      // The one red is the clinical SAM red, so "error" and "severe" never
      // disagree.
      error: light ? const Color(0xFFC62828) : const Color(0xFFF2B8B5),
      onError: light ? Colors.white : const Color(0xFF601410),
      errorContainer: light ? const Color(0xFFFFEBEE) : const Color(0xFF3D1414),
      onErrorContainer:
          light ? const Color(0xFF5A1212) : const Color(0xFFF2B4B4),
      // No seed-coloured wash on elevated surfaces.
      surfaceTint: Colors.transparent,
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
