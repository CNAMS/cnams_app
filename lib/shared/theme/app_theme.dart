import 'package:flutter/material.dart';

/// App theme. Light-first, high-contrast, outdoor-legible (screens must not
/// wash out in courtyard daylight). Base font 16 sp; minimum touch target 48 dp.
///
/// See docs/PRODUCTION_ROADMAP.md — cross-cutting accessibility.
class AppTheme {
  const AppTheme._();

  /// Classification colours. Never used alone — always paired with text + icon
  /// so the result is readable under colour-vision deficiency and greyscale
  /// photocopying.
  static const Color normal = Color(0xFF2E7D32); // green
  static const Color caution = Color(0xFFF9A825); // yellow
  static const Color severe = Color(0xFFC62828); // red

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: normal),
      brightness: Brightness.light,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontSizeFactor: 1.0),
    );
  }
}
