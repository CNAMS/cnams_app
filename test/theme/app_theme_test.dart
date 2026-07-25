// Per-role theme tests: each role builds a light and dark theme with the right
// brightness and its own primary, and the classification palette is untouched.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/shared/theme/app_theme.dart';

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
}
