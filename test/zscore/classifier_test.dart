// WHO classification tests: each cut-off, precedence, oedema, indeterminate.

import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/core/zscore/classifier.dart';

void main() {
  test('oedema forces SAM regardless of z-scores', () {
    expect(
      classify(whz: 0.5, muacMm: 140, oedema: true),
      GrowthClass.sam,
    );
  });

  group('weight-for-height/length bands', () {
    test('below -3 is SAM', () {
      expect(classify(whz: -3.1, oedema: false), GrowthClass.sam);
    });
    test('between -3 and -2 is MAM', () {
      expect(classify(whz: -2.5, oedema: false), GrowthClass.mam);
    });
    test('within normal range is normal', () {
      expect(classify(whz: 0, oedema: false), GrowthClass.normal);
    });
    test('above +2 is overweight', () {
      expect(classify(whz: 2.5, oedema: false), GrowthClass.overweight);
    });
  });

  group('MUAC bands', () {
    test('below 115 mm is SAM', () {
      expect(classify(muacMm: 110, oedema: false), GrowthClass.sam);
    });
    test('115-124 mm is MAM', () {
      expect(classify(muacMm: 120, oedema: false), GrowthClass.mam);
    });
    test('125 mm and above is normal', () {
      expect(classify(muacMm: 130, oedema: false), GrowthClass.normal);
    });
  });

  test('the worst signal wins (MUAC SAM beats WHZ normal)', () {
    expect(
      classify(whz: 0.2, muacMm: 110, oedema: false),
      GrowthClass.sam,
    );
  });

  test('malnutrition outranks overweight', () {
    // WHZ says overweight, MUAC says MAM -> MAM.
    expect(
      classify(whz: 2.5, muacMm: 120, oedema: false),
      GrowthClass.mam,
    );
  });

  test('no usable signal is indeterminate', () {
    expect(classify(oedema: false), GrowthClass.indeterminate);
  });
}
