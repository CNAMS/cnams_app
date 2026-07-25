// Backoff policy tests.

import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/sync/backoff.dart';

void main() {
  test('no delay before the first attempt', () {
    expect(backoffFor(0), Duration.zero);
  });

  test('doubles from the 30s base', () {
    expect(backoffFor(1), const Duration(seconds: 30));
    expect(backoffFor(2), const Duration(seconds: 60));
    expect(backoffFor(3), const Duration(seconds: 120));
    expect(backoffFor(4), const Duration(seconds: 240));
  });

  test('is capped at one hour and never overflows', () {
    expect(backoffFor(20), syncBackoffCap);
    expect(backoffFor(1000), syncBackoffCap);
  });
}
