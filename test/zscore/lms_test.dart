// LMS math tests. Expected values are computed by hand from the formula, not
// taken from any reference dataset, so these verify the engine's arithmetic
// independently of the WHO tables.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/zscore/lms.dart';

void main() {
  group('lmsZScore', () {
    test('the median maps to z = 0 for any L, M, S', () {
      expect(lmsZScore(10, 1, 10, 0.1), closeTo(0, 1e-9));
      expect(lmsZScore(7.5, -0.3, 7.5, 0.12), closeTo(0, 1e-9));
      expect(lmsZScore(50, 0, 50, 0.05), closeTo(0, 1e-9)); // L == 0 branch
    });

    test('linear case (L = 1): z = (y - M) / (M*S)', () {
      // M = 10, S = 0.1  ->  M*S = 1, so z equals (y - 10).
      expect(lmsZScore(11, 1, 10, 0.1), closeTo(1, 1e-9));
      expect(lmsZScore(9, 1, 10, 0.1), closeTo(-1, 1e-9));
      expect(lmsZScore(12, 1, 10, 0.1), closeTo(2, 1e-9));
      expect(lmsZScore(13, 1, 10, 0.1), closeTo(3, 1e-9)); // exactly at +3
    });

    test('logarithmic case (L = 0): z = ln(y/M) / S', () {
      // y = M * exp(S) -> z = 1.
      final y = 10 * math.exp(0.1);
      expect(lmsZScore(y, 0, 10, 0.1), closeTo(1, 1e-9));
    });

    test('extreme high value with L = -1 uses WHO extrapolation', () {
      // L=-1, M=10, S=0.1. Raw z would be 5.0, but WHO rescales beyond +3 using
      // the +2..+3 SD gap:
      //   SD3 = 10/(1-0.3) = 14.28571, SD2 = 10/(1-0.2) = 12.5
      //   z = 3 + (20 - 14.28571) / (14.28571 - 12.5) = 6.2
      expect(lmsZScore(20, -1, 10, 0.1), closeTo(6.2, 1e-3));
    });

    test('extreme low value with L = -1 uses WHO extrapolation', () {
      // SD-3 = 10/(1+0.3) = 7.69231, SD-2 = 10/(1+0.2) = 8.33333
      //   z = -3 + (6 - 7.69231) / (8.33333 - 7.69231) = -5.6400
      expect(lmsZScore(6, -1, 10, 0.1), closeTo(-5.64, 1e-2));
    });

    test('linear extrapolation matches the raw score (no distortion)', () {
      // With L = 1 the tail is already linear, so >3 extrapolation is a no-op.
      expect(lmsZScore(14, 1, 10, 0.1), closeTo(4, 1e-9));
      expect(lmsZScore(6, 1, 10, 0.1), closeTo(-4, 1e-9));
    });
  });

  group('lmsValueAtZ', () {
    test('inverts the transform: value at z then z of value round-trips', () {
      const l = -0.3, m = 8.0, s = 0.11;
      for (final z in [-2.0, -1.0, 0.0, 1.5, 2.0]) {
        final value = lmsValueAtZ(z, l, m, s);
        expect(lmsZScore(value, l, m, s), closeTo(z, 1e-9));
      }
    });
  });
}
