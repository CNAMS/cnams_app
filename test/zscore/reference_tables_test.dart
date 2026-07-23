// Reference-table lookup tests: interpolation, exact hits, and out-of-range.

import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/zscore/reference_tables.dart';

LmsTable _table() => LmsTable(
      indicator: GrowthIndicator.weightForAge,
      sex: Sex.male,
      points: const [
        LmsPoint(0, Lms(0.3, 3.3, 0.14)),
        LmsPoint(30, Lms(0.2, 4.5, 0.13)),
        LmsPoint(60, Lms(0.1, 5.6, 0.12)),
      ],
    );

void main() {
  test('exact key returns that point unchanged', () {
    final lms = _table().at(30)!;
    expect(lms.l, 0.2);
    expect(lms.m, 4.5);
    expect(lms.s, 0.13);
  });

  test('interpolates linearly between two points', () {
    // Midway between x=0 and x=30, each parameter is the average.
    final lms = _table().at(15)!;
    expect(lms.l, closeTo(0.25, 1e-9));
    expect(lms.m, closeTo(3.9, 1e-9));
    expect(lms.s, closeTo(0.135, 1e-9));
  });

  test('endpoints are returned exactly', () {
    expect(_table().at(0)!.m, 3.3);
    expect(_table().at(60)!.m, 5.6);
  });

  test('out-of-range lookups return null', () {
    expect(_table().at(-1), isNull);
    expect(_table().at(61), isNull);
  });

  test('ReferenceTables resolves by indicator and sex', () {
    final tables = ReferenceTables([_table()]);
    expect(
      tables.table(GrowthIndicator.weightForAge, Sex.male),
      isNotNull,
    );
    expect(
      tables.table(GrowthIndicator.weightForAge, Sex.female),
      isNull,
    );
  });
}
