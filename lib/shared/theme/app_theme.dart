import 'package:flutter/material.dart';

import 'package:cgms_app/core/zscore/classification.dart';

/// App theme, tuned for the field rather than the lab.
///
/// The phone is used outdoors in a courtyard, often in bright sun, sometimes by
/// a worker with colour-vision deficiency, and the parent card may be
/// photocopied in greyscale. So: high contrast, a large base font, generous
/// touch targets, and classification colours that are always paired with a word
/// and an icon — never colour alone.
///
/// See docs/PRODUCTION_ROADMAP.md — cross-cutting accessibility.
class AppTheme {
  const AppTheme._();

  /// Minimum interactive size — comfortably above the 48 dp floor.
  static const double minTouchTarget = 48;

  /// Base body text size; system text scaling is honoured on top of this.
  static const double baseFontSize = 16;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00695C),
      brightness: Brightness.light,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      visualDensity: VisualDensity.comfortable,
      textTheme: base.textTheme.apply(
        bodyColor: const Color(0xFF1A1A1A),
        displayColor: const Color(0xFF1A1A1A),
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
