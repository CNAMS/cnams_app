// 24-month boundary and position-correction tests.

import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/zscore/anthropometry.dart';
import 'package:cgms_app/core/zscore/reference_tables.dart';

void main() {
  test('recumbent is expected up to but not including 731 days', () {
    expect(isRecumbentExpected(730), isTrue);
    expect(isRecumbentExpected(731), isFalse);
  });

  group('position correction', () {
    test('young child measured standing gains 0.7 cm toward recumbent', () {
      expect(
        correctedStatureMm(
          ageDays: 365,
          measuredMm: 800,
          measuredRecumbent: false,
        ),
        807,
      );
    });

    test('young child measured recumbent is unchanged', () {
      expect(
        correctedStatureMm(
          ageDays: 365,
          measuredMm: 800,
          measuredRecumbent: true,
        ),
        800,
      );
    });

    test('older child measured recumbent loses 0.7 cm toward standing', () {
      expect(
        correctedStatureMm(
          ageDays: 900,
          measuredMm: 900,
          measuredRecumbent: true,
        ),
        893,
      );
    });

    test('older child measured standing is unchanged', () {
      expect(
        correctedStatureMm(
          ageDays: 900,
          measuredMm: 900,
          measuredRecumbent: false,
        ),
        900,
      );
    });
  });

  test('weight indicator switches at the boundary', () {
    expect(weightForStatureIndicator(730), GrowthIndicator.weightForLength);
    expect(weightForStatureIndicator(731), GrowthIndicator.weightForHeight);
  });
}
