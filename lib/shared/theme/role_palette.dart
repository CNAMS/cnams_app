import 'package:flutter/material.dart';

import 'package:cgms_app/core/auth/app_role.dart';

/// Ankur's role colours — one brand, five skins — as exact values.
///
/// Why exact values instead of `ColorScheme.fromSeed`: the tonal algorithm
/// moves the seed. It greyed the AWW teal, turned the parent amber brown, and
/// tinted every card, chip and input with a seed-coloured grey that clashed
/// with the sand page. Here each role's accent is used as specified and the
/// neutrals are shared and clean.
///
/// Why these hues: role colour must never be mistaken for a result. The old
/// supervisor green was the exact "Normal" green (#2E7D32), the doctor blue the
/// exact "Overweight" blue (#1565C0), and the parent amber sat beside "MAM".
/// Every accent below is clear of the clinical palette in [AppTheme.styleFor].
///
/// Contrast (WCAG): white on every light accent ≥ 6.0:1, every light accent on
/// its page tint ≥ 5.6:1, the dark page colour on every dark accent ≥ 7.7:1,
/// and text on each subtle container ≥ 8.7:1. The portal (cnams_frontend,
/// docs/DESIGN.md) uses this same table.
@immutable
class RolePalette {
  const RolePalette({
    required this.accent,
    required this.accentHover,
    required this.accentSubtle,
    required this.onAccentSubtle,
    required this.pageTint,
    required this.darkAccent,
    required this.darkAccentHover,
    required this.darkAccentSubtle,
    required this.darkOnAccentSubtle,
  });

  final Color accent;
  final Color accentHover;
  final Color accentSubtle;
  final Color onAccentSubtle;

  /// The light page background — the role's "surface temperature".
  final Color pageTint;

  final Color darkAccent;
  final Color darkAccentHover;
  final Color darkAccentSubtle;
  final Color darkOnAccentSubtle;

  static RolePalette of(AppRole role) => switch (role) {
        // Teal on warm sand — the field theme and the brand anchor.
        AppRole.aww => const RolePalette(
            accent: Color(0xFF00695C),
            accentHover: Color(0xFF00584D),
            accentSubtle: Color(0xFFE0EDEB),
            onAccentSubtle: Color(0xFF002F29),
            pageTint: Color(0xFFFBF8F1),
            darkAccent: Color(0xFF4DB6AC),
            darkAccentHover: Color(0xFF71C5BD),
            darkAccentSubtle: Color(0xFF1D3635),
            darkOnAccentSubtle: Color(0xFFAFDEDA),
          ),
        // Indigo — oversight. Was sprout green, identical to "Normal".
        AppRole.supervisor => const RolePalette(
            accent: Color(0xFF3949AB),
            accentHover: Color(0xFF303D90),
            accentSubtle: Color(0xFFE7E9F5),
            onAccentSubtle: Color(0xFF1A214D),
            pageTint: Color(0xFFF5F6FB),
            darkAccent: Color(0xFF9FA8DA),
            darkAccentHover: Color(0xFFB2B9E1),
            darkAccentSubtle: Color(0xFF2F3340),
            darkOnAccentSubtle: Color(0xFFD4D8EE),
          ),
        // Violet — clinical, and no longer the "Overweight" blue.
        AppRole.doctor => const RolePalette(
            accent: Color(0xFF6A40B0),
            accentHover: Color(0xFF593694),
            accentSubtle: Color(0xFFEDE8F6),
            onAccentSubtle: Color(0xFF301D4F),
            pageTint: Color(0xFFF8F6FC),
            darkAccent: Color(0xFFB9A2E0),
            darkAccentHover: Color(0xFFC7B5E6),
            darkAccentSubtle: Color(0xFF343241),
            darkOnAccentSubtle: Color(0xFFE0D5F1),
          ),
        // Rose — warm for families; was an amber that read as "MAM" and gave
        // white text only 2.6:1.
        AppRole.parent => const RolePalette(
            accent: Color(0xFFA8396F),
            accentHover: Color(0xFF8D305D),
            accentSubtle: Color(0xFFF5E7EE),
            onAccentSubtle: Color(0xFF4C1A32),
            pageTint: Color(0xFFFCF6F8),
            darkAccent: Color(0xFFEDA1C2),
            darkAccentHover: Color(0xFFF1B4CE),
            darkAccentSubtle: Color(0xFF40313A),
            darkOnAccentSubtle: Color(0xFFF7D5E4),
          ),
        // Slate on cool grey — a light console, deliberately not dark.
        AppRole.admin => const RolePalette(
            accent: Color(0xFF4B5570),
            accentHover: Color(0xFF3F475E),
            accentSubtle: Color(0xFFE9EBEE),
            onAccentSubtle: Color(0xFF222632),
            pageTint: Color(0xFFEEF1F5),
            darkAccent: Color(0xFFA9B4CC),
            darkAccentHover: Color(0xFFBAC3D6),
            darkAccentSubtle: Color(0xFF31363C),
            darkOnAccentSubtle: Color(0xFFD8DDE8),
          ),
      };

  /// The accent for a brightness.
  Color accentFor(Brightness b) => b == Brightness.light ? accent : darkAccent;
}

/// Shared neutrals: warm "stone" greys that sit on the sand tint and stay
/// neutral on the cooler ones. Every text tone is ≥ 4.5:1 on its card.
abstract final class Neutrals {
  // Light
  static const card = Color(0xFFFFFFFF);
  static const sunken = Color(0xFFF6F5F3);
  static const high = Color(0xFFEFEDEA);
  static const highest = Color(0xFFE7E5E2);
  static const line = Color(0xFFE7E5E2);
  static const inputBorder = Color(0xFF8A847D); // 3.7:1 — WCAG 1.4.11
  static const text = Color(0xFF1C1B19); // 17.2:1
  static const textMuted = Color(0xFF57534E); // 7.6:1

  // Dark
  static const darkPage = Color(0xFF0F1214);
  static const darkLowest = Color(0xFF0B0E10);
  static const darkCard = Color(0xFF171B1E);
  static const darkContainer = Color(0xFF1B1F23);
  static const darkHigh = Color(0xFF22272B);
  static const darkHighest = Color(0xFF2A3035);
  static const darkLine = Color(0xFF2A3035);
  static const darkInputBorder = Color(0xFF6B737B); // 3.6:1
  static const darkText = Color(0xFFECEEF0); // 14.9:1
  static const darkTextMuted = Color(0xFFA3AAB1); // 7.4:1
}
