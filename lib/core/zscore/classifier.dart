// WHO growth classification. Pure Dart.
//
// Combines the available signals into a single band, worst-first:
//   - Bilateral oedema forces SAM, regardless of any z-score (WHO rule).
//   - Weight-for-height/length z (wasting): < -3 SAM, [-3,-2) MAM, > +2 overweight.
//   - MUAC (6-59 months): < 115 mm SAM, 115-124 mm MAM.
//   - Malnutrition outranks overweight outranks normal.
//   - With no usable signal at all, the result is indeterminate — we never guess.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P2.

import 'package:cgms_app/core/zscore/classification.dart';

/// MUAC cut-offs in millimetres (6-59 months).
const int muacSamMm = 115;
const int muacMamMm = 125;

/// Classify from whatever signals are available.
///
/// [whz] is the weight-for-height/length z-score (null if it could not be
/// computed). [muacMm] is mid-upper-arm circumference (null if not measured or
/// not applicable for the age). [oedema] is the clinical override.
GrowthClass classify({
  double? whz,
  int? muacMm,
  required bool oedema,
}) {
  if (oedema) return GrowthClass.sam;

  var sawSignal = false;
  var sam = false;
  var mam = false;
  var overweight = false;

  if (whz != null) {
    sawSignal = true;
    if (whz < -3) {
      sam = true;
    } else if (whz < -2) {
      mam = true;
    } else if (whz > 2) {
      overweight = true;
    }
  }

  if (muacMm != null) {
    sawSignal = true;
    if (muacMm < muacSamMm) {
      sam = true;
    } else if (muacMm < muacMamMm) {
      mam = true;
    }
  }

  if (!sawSignal) return GrowthClass.indeterminate;
  if (sam) return GrowthClass.sam;
  if (mam) return GrowthClass.mam;
  if (overweight) return GrowthClass.overweight;
  return GrowthClass.normal;
}
