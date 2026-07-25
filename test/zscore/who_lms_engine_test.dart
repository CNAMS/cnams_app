// WhoLmsEngine tests.
//
// The tables here are SYNTHETIC — chosen so the expected z-scores can be worked
// out by hand — not WHO data. They verify the engine wires inputs, units,
// lookup, the boundary correction, classification and flags together correctly.
// Validation against the real WHO tables is the golden-corpus task at Gate G2.

import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/core/zscore/reference_tables.dart';
import 'package:cgms_app/core/zscore/who_lms_engine.dart';
import 'package:cgms_app/core/zscore/zscore_engine.dart';

ReferenceTables _tables() => ReferenceTables([
      LmsTable(
        indicator: GrowthIndicator.weightForAge,
        sex: Sex.male,
        points: const [
          LmsPoint(0, Lms(-0.2, 3.3, 0.14)),
          LmsPoint(365, Lms(-0.2, 10.0, 0.10)),
          LmsPoint(1826, Lms(-0.2, 18.0, 0.12)),
        ],
      ),
      LmsTable(
        indicator: GrowthIndicator.lengthOrHeightForAge,
        sex: Sex.male,
        points: const [
          LmsPoint(0, Lms(1, 50.0, 0.04)),
          LmsPoint(365, Lms(1, 75.0, 0.04)),
          LmsPoint(1826, Lms(1, 110.0, 0.04)),
        ],
      ),
      LmsTable(
        indicator: GrowthIndicator.weightForLength,
        sex: Sex.male,
        points: const [
          LmsPoint(45.0, Lms(-0.5, 2.5, 0.08)),
          LmsPoint(75.0, Lms(-0.5, 9.5, 0.08)),
          LmsPoint(110.0, Lms(-0.5, 18.0, 0.08)),
        ],
      ),
      LmsTable(
        indicator: GrowthIndicator.muacForAge,
        sex: Sex.male,
        points: const [
          LmsPoint(182, Lms(1, 14.0, 0.08)),
          LmsPoint(365, Lms(1, 15.0, 0.08)),
          LmsPoint(1826, Lms(1, 16.0, 0.08)),
        ],
      ),
    ]);

void main() {
  final engine = WhoLmsEngine(_tables());

  test('a child at every median scores ~0 and normal', () {
    final r = engine.compute(
      const ZScoreInput(
        sex: Sex.male,
        ageDays: 365,
        weightG: 10000, // 10 kg == M
        lengthMm: 750, // 75 cm == M, recumbent as expected
        muacMm: 150, // 15 cm == M
        recumbent: true,
      ),
    );
    expect(r.waz, closeTo(0, 1e-9));
    expect(r.haz, closeTo(0, 1e-9));
    expect(r.maz, closeTo(0, 1e-9));
    // Weight-for-length median is 9.5 kg, so 10 kg sits slightly above 0.
    expect(r.whz, closeTo(0.633, 1e-3));
    expect(r.classification, GrowthClass.normal);
    expect(r.flags, isEmpty);
    expect(r.engineVersion, WhoLmsEngine.version);
  });

  test('a low weight-for-length is SAM (with WHO tail extrapolation)', () {
    final r = engine.compute(
      const ZScoreInput(
        sex: Sex.male,
        ageDays: 365,
        weightG: 7000,
        lengthMm: 750,
        muacMm: 150,
        recumbent: true,
      ),
    );
    expect(r.whz, closeTo(-4.003, 1e-2));
    expect(r.classification, GrowthClass.sam);
  });

  test('MUAC below 115 mm is SAM even when weight-for-length is fine', () {
    final r = engine.compute(
      const ZScoreInput(
        sex: Sex.male,
        ageDays: 365,
        weightG: 10000,
        lengthMm: 750,
        muacMm: 110,
        recumbent: true,
      ),
    );
    expect(r.classification, GrowthClass.sam);
  });

  test('oedema forces SAM regardless of measurements', () {
    final r = engine.compute(
      const ZScoreInput(
        sex: Sex.male,
        ageDays: 365,
        weightG: 10000,
        lengthMm: 750,
        oedema: true,
      ),
    );
    expect(r.classification, GrowthClass.sam);
  });

  test('measuring a young child standing flags a position correction', () {
    final r = engine.compute(
      const ZScoreInput(
        sex: Sex.male,
        ageDays: 365,
        weightG: 10000,
        lengthMm: 743, // +7 mm correction -> 750 mm == median again
        recumbent: false,
      ),
    );
    expect(r.flags, contains('position_corrected'));
    expect(r.haz, closeTo(0, 1e-9)); // correction lands back on the median
  });

  test('with no anthropometry the result is indeterminate', () {
    final r = engine.compute(
      const ZScoreInput(sex: Sex.male, ageDays: 365),
    );
    expect(r.waz, isNull);
    expect(r.haz, isNull);
    expect(r.whz, isNull);
    expect(r.classification, GrowthClass.indeterminate);
  });

  test('an age past the table range flags out-of-range and returns null', () {
    final r = engine.compute(
      const ZScoreInput(sex: Sex.male, ageDays: 5000, weightG: 12000),
    );
    expect(r.waz, isNull);
    expect(r.flags, contains('waz_out_of_range'));
  });

  test('an implausible weight is flagged but still scored', () {
    final r = engine.compute(
      const ZScoreInput(sex: Sex.male, ageDays: 365, weightG: 100),
    );
    expect(r.flags, contains('weight_implausible'));
    expect(r.waz, isNotNull);
  });
}
