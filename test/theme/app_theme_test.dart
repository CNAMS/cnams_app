// Per-role theme tests: each role builds a light and dark theme with the right
// brightness and its own primary, and the classification palette is untouched.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/shared/theme/app_theme.dart';
import 'package:cgms_app/shared/theme/role_palette.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('every role builds a light and dark theme', () {
    for (final role in AppRole.values) {
      final light = AppTheme.forRole(role, Brightness.light);
      final dark = AppTheme.forRole(role, Brightness.dark);
      expect(light.colorScheme.brightness, Brightness.light);
      expect(dark.colorScheme.brightness, Brightness.dark);
    }
  });

  test('roles have distinct primary colours', () {
    final primaries = {
      for (final role in AppRole.values)
        AppTheme.forRole(role, Brightness.light).colorScheme.primary,
    };
    // Five roles, five distinct primaries.
    expect(primaries.length, AppRole.values.length);
  });

  test('AWW light theme is the default entry point', () {
    expect(
      AppTheme.light().colorScheme.primary,
      AppTheme.forRole(AppRole.aww, Brightness.light).colorScheme.primary,
    );
  });

  test('classification colours do not change with role or brightness', () {
    // styleFor is role-independent — same clinical colours everywhere.
    expect(AppTheme.styleFor(GrowthClass.sam).color, const Color(0xFFC62828));
    expect(
        AppTheme.styleFor(GrowthClass.normal).color, const Color(0xFF2E7D32));
    expect(
      AppTheme.styleFor(GrowthClass.indeterminate).color,
      const Color(0xFF616161),
    );
  });

  test('no role accent can be mistaken for a classification colour', () {
    final clinical = {
      for (final c in GrowthClass.values) AppTheme.styleFor(c).color,
    };
    for (final role in AppRole.values) {
      final primary =
          AppTheme.forRole(role, Brightness.light).colorScheme.primary;
      expect(clinical.contains(primary), isFalse, reason: '$role');
    }
  });

  test('role accents are used exactly, not shifted by a seed algorithm', () {
    for (final role in AppRole.values) {
      final p = RolePalette.of(role);
      expect(
        AppTheme.forRole(role, Brightness.light).colorScheme.primary,
        p.accent,
      );
      expect(
        AppTheme.forRole(role, Brightness.dark).colorScheme.primary,
        p.darkAccent,
      );
    }
  });

  test('text on every accent and container meets WCAG AA', () {
    for (final role in AppRole.values) {
      for (final b in Brightness.values) {
        final s = AppTheme.forRole(role, b).colorScheme;
        expect(_contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5),
            reason: '$role $b onPrimary');
        expect(_contrast(s.primary, s.surface), greaterThanOrEqualTo(4.5),
            reason: '$role $b primary on page');
        expect(
          _contrast(s.onPrimaryContainer, s.primaryContainer),
          greaterThanOrEqualTo(7),
          reason: '$role $b on container',
        );
        expect(_contrast(s.onSurfaceVariant, s.surfaceContainerLow),
            greaterThanOrEqualTo(4.5),
            reason: '$role $b muted text on card');
      }
    }
  });
}
