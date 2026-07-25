// Reference-loader parsing tests (the pure part; no asset I/O).

import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/reference/reference_loader.dart';
import 'package:cgms_app/core/zscore/reference_tables.dart';

const _json = '''
{
  "source": "test",
  "tables": [
    {
      "indicator": "weightForAge",
      "sex": "female",
      "points": [
        {"x": 60, "l": 0.1, "m": 5.6, "s": 0.12},
        {"x": 0,  "l": 0.3, "m": 3.2, "s": 0.14}
      ]
    }
  ]
}
''';

void main() {
  test('parses tables, maps indicator/sex, and sorts points by x', () {
    final tables = parseReferenceTables(_json);
    final table = tables.table(GrowthIndicator.weightForAge, Sex.female);

    expect(table, isNotNull);
    // Points sorted ascending even though the JSON listed x=60 first.
    expect(table!.points.first.x, 0);
    expect(table.points.last.x, 60);
    expect(table.at(0)!.m, 3.2);
  });

  test('the empty placeholder parses to no tables (fail-safe)', () {
    final tables = parseReferenceTables('{"tables": []}');
    expect(tables.isEmpty, isTrue);
    expect(tables.table(GrowthIndicator.weightForAge, Sex.male), isNull);
  });
}
