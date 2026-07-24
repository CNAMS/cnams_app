// Growth-band series tests.

import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/zscore/reference_tables.dart';
import 'package:cgms_app/features/history/growth_series.dart';

void main() {
  test('null or empty table yields no bands', () {
    expect(bandsFor(null), isNull);
    expect(
      bandsFor(
        LmsTable(
          indicator: GrowthIndicator.weightForAge,
          sex: Sex.male,
          points: const [],
        ),
      ),
      isNull,
    );
  });

  test('median band equals M, and the SD bands straddle it', () {
    final table = LmsTable(
      indicator: GrowthIndicator.weightForAge,
      sex: Sex.male,
      points: const [
        LmsPoint(0, Lms(1, 3.0, 0.10)),
        LmsPoint(365, Lms(1, 10.0, 0.10)),
      ],
    );

    final bands = bandsFor(table)!;
    // Median is M at each point.
    expect(bands.median.map((p) => p.y), [3.0, 10.0]);
    // -2SD below and +2SD above the median, symmetric for L = 1.
    expect(bands.minus2[1].y, lessThan(10.0));
    expect(bands.plus2[1].y, greaterThan(10.0));
    // +3 further out than +2.
    expect(bands.plus3[1].y, greaterThan(bands.plus2[1].y));
    expect(bands.minus3[1].y, lessThan(bands.minus2[1].y));
    // x carried through.
    expect(bands.median.map((p) => p.x), [0, 365]);
  });
}
