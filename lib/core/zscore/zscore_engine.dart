// Pure-Dart WHO LMS z-score engine.
//
// LAYERING RULE: this file (and everything in core/zscore/) MUST NOT import
// Flutter. The engine is pure Dart so it can be tested headlessly and diffed
// against the Python / WHO Anthro reference (Gate G2).
//
// See docs/PRODUCTION_ROADMAP.md — Phase P2.

import 'package:cgms_app/core/zscore/classification.dart';

/// Anthropometric inputs for a single measurement.
class ZScoreInput {
  const ZScoreInput({
    required this.sex,
    required this.ageDays,
    this.weightG,
    this.lengthMm,
    this.muacMm,
    this.recumbent,
    this.oedema = false,
  });

  final Sex sex;
  final int ageDays;
  final int? weightG;
  final int? lengthMm;
  final int? muacMm;

  /// True = recumbent (length), false = standing (height). Position correction
  /// is applied at the 24-month boundary.
  final bool? recumbent;

  /// Clinical override: oedema forces SAM regardless of z-score (WHO rule).
  final bool oedema;
}

/// Computed z-scores and the resulting classification.
class ZScoreResult {
  const ZScoreResult({
    this.waz,
    this.haz,
    this.whz,
    this.maz,
    required this.classification,
    required this.engineVersion,
    this.flags = const [],
  });

  final double? waz; // weight-for-age
  final double? haz; // height/length-for-age
  final double? whz; // weight-for-height/length
  final double? maz; // MUAC-for-age

  final GrowthClass classification;
  final String engineVersion;
  final List<String> flags;
}

enum Sex { male, female }

/// The WHO LMS engine. Stateless and deterministic.
abstract class ZScoreEngine {
  /// Bumped whenever the computation changes; stored on every measurement row
  /// so historical records remain reproducible/auditable.
  static const String version = '0.0.0-scaffold';

  /// Compute z-scores and classification for a single measurement.
  ///
  /// TODO(P2): implement WHO LMS lookup + interpolation against bundled
  /// reference tables, position correction at 24 months, oedema override,
  /// and plausibility flagging.
  ZScoreResult compute(ZScoreInput input);
}
