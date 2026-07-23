// The concrete WHO LMS engine. Pure Dart — reference tables are injected, so
// this layer never touches Flutter or the filesystem.
//
// Units, fixed at the boundary so callers can't get them wrong:
//   - weight in grams, converted to kg for the tables;
//   - length/height in mm, corrected for position then converted to cm;
//   - MUAC in mm, converted to cm;
//   - -for-age tables are keyed by age in days; weight-for-length/height tables
//     by stature in cm.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P2 (Gate G2).

import 'package:cgms_app/core/zscore/anthropometry.dart';
import 'package:cgms_app/core/zscore/classifier.dart';
import 'package:cgms_app/core/zscore/lms.dart';
import 'package:cgms_app/core/zscore/reference_tables.dart';
import 'package:cgms_app/core/zscore/zscore_engine.dart';

class WhoLmsEngine implements ZScoreEngine {
  WhoLmsEngine(this.tables);

  final ReferenceTables tables;

  /// Bumped whenever the computation changes; stored on every measurement row
  /// so historical records stay reproducible and auditable.
  static const String version = '1.0.0-lms';

  // MUAC-for-age cut-offs apply from 6 to 59 completed months.
  static const int _muacMinDays = 182;
  static const int _muacMaxDays = 1826;

  @override
  ZScoreResult compute(ZScoreInput input) {
    final flags = <String>[];
    final sex = input.sex;

    final double? waz = _weightForAge(input, sex, flags);
    final int? statureMm = _correctedStature(input, flags);
    final double? haz = _lengthForAge(input, sex, statureMm, flags);
    final double? whz = _weightForStature(input, sex, statureMm, flags);
    final double? maz = _muacForAge(input, sex, flags);

    // MUAC cut-offs only inform the classification within 6-59 months.
    final int? muacForClass = (input.muacMm != null &&
            input.ageDays >= _muacMinDays &&
            input.ageDays < _muacMaxDays)
        ? input.muacMm
        : null;

    final classification = classify(
      whz: whz,
      muacMm: muacForClass,
      oedema: input.oedema,
    );

    return ZScoreResult(
      waz: waz,
      haz: haz,
      whz: whz,
      maz: maz,
      classification: classification,
      engineVersion: version,
      flags: flags,
    );
  }

  double? _weightForAge(ZScoreInput input, Sex sex, List<String> flags) {
    final weightG = input.weightG;
    if (weightG == null) return null;
    _flagIf(weightG < 500 || weightG > 40000, 'weight_implausible', flags);
    final lms = tables
        .table(GrowthIndicator.weightForAge, sex)
        ?.at(input.ageDays.toDouble());
    if (lms == null) {
      flags.add('waz_out_of_range');
      return null;
    }
    return lmsZScore(weightG / 1000, lms.l, lms.m, lms.s);
  }

  int? _correctedStature(ZScoreInput input, List<String> flags) {
    final lengthMm = input.lengthMm;
    if (lengthMm == null) return null;
    _flagIf(lengthMm < 300 || lengthMm > 1300, 'length_implausible', flags);

    final expectRecumbent = isRecumbentExpected(input.ageDays);
    final measuredRecumbent = input.recumbent ?? expectRecumbent;
    _flagIf(
      input.recumbent != null && input.recumbent != expectRecumbent,
      'position_corrected',
      flags,
    );

    return correctedStatureMm(
      ageDays: input.ageDays,
      measuredMm: lengthMm,
      measuredRecumbent: measuredRecumbent,
    );
  }

  double? _lengthForAge(
    ZScoreInput input,
    Sex sex,
    int? statureMm,
    List<String> flags,
  ) {
    if (statureMm == null) return null;
    final lms = tables
        .table(GrowthIndicator.lengthOrHeightForAge, sex)
        ?.at(input.ageDays.toDouble());
    if (lms == null) {
      flags.add('haz_out_of_range');
      return null;
    }
    return lmsZScore(statureMm / 10, lms.l, lms.m, lms.s);
  }

  double? _weightForStature(
    ZScoreInput input,
    Sex sex,
    int? statureMm,
    List<String> flags,
  ) {
    final weightG = input.weightG;
    if (weightG == null || statureMm == null) return null;
    final indicator = weightForStatureIndicator(input.ageDays);
    final lms = tables.table(indicator, sex)?.at(statureMm / 10);
    if (lms == null) {
      flags.add('whz_out_of_range');
      return null;
    }
    return lmsZScore(weightG / 1000, lms.l, lms.m, lms.s);
  }

  double? _muacForAge(ZScoreInput input, Sex sex, List<String> flags) {
    final muacMm = input.muacMm;
    if (muacMm == null) return null;
    _flagIf(muacMm < 50 || muacMm > 300, 'muac_implausible', flags);
    final lms = tables
        .table(GrowthIndicator.muacForAge, sex)
        ?.at(input.ageDays.toDouble());
    if (lms == null) {
      flags.add('maz_out_of_range');
      return null;
    }
    return lmsZScore(muacMm / 10, lms.l, lms.m, lms.s);
  }

  static void _flagIf(bool condition, String flag, List<String> flags) {
    if (condition) flags.add(flag);
  }
}
