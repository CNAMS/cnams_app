// Dependency pins that protect release builds.
//
// path_provider_android 2.3.x is built on package:jni and, in release APKs,
// fails with "ClassNotFoundException: Didn't find class
// Landroid/content/Context;" — so the local database never opens on a real
// phone, while debug builds and these tests pass. The pin in pubspec.yaml
// keeps the Pigeon-based 2.2.x line; this test stops it drifting silently.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('path_provider_android stays on the pre-jni 2.2.x line', () {
    final lock = File('pubspec.lock').readAsStringSync();
    final match = RegExp(
      r'\n  path_provider_android:\n(?:    .*\n)*?    version: "([^"]+)"',
    ).firstMatch(lock);
    expect(match, isNotNull, reason: 'path_provider_android not in lockfile');
    final version = match!.group(1)!;
    expect(
      version.startsWith('2.2.'),
      isTrue,
      reason: 'path_provider_android $version uses package:jni, which breaks '
          'getApplicationDocumentsDirectory() in release builds. Verify a '
          'release APK on a device before moving off 2.2.x.',
    );
  });
}
