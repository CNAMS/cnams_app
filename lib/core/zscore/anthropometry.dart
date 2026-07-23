// Length/height boundary handling at 24 months. Pure Dart.
//
// WHO measures children under 24 months lying down (recumbent length) and older
// children standing (height). A child measured in the "wrong" position is
// corrected by 0.7 cm: standing is ~0.7 cm shorter than lying, so we add 0.7 cm
// when we need a recumbent value and subtract it when we need a standing one.
// The same boundary decides whether weight is scored against weight-for-length
// or weight-for-height.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P2.

import 'package:cgms_app/core/zscore/reference_tables.dart';

/// 24 months, expressed in days, as WHO defines the length/height cut-over.
const int lengthHeightBoundaryDays = 731;

/// The 0.7 cm (7 mm) recumbent-vs-standing correction.
const int positionCorrectionMm = 7;

/// Whether a child of [ageDays] is expected to be measured recumbent (lying).
bool isRecumbentExpected(int ageDays) => ageDays < lengthHeightBoundaryDays;

/// Convert a raw stature reading to the position the reference expects for this
/// age, applying the 0.7 cm correction when the measured position differs.
int correctedStatureMm({
  required int ageDays,
  required int measuredMm,
  required bool measuredRecumbent,
}) {
  final expectRecumbent = isRecumbentExpected(ageDays);
  if (expectRecumbent && !measuredRecumbent) {
    return measuredMm + positionCorrectionMm; // standing -> recumbent
  }
  if (!expectRecumbent && measuredRecumbent) {
    return measuredMm - positionCorrectionMm; // recumbent -> standing
  }
  return measuredMm;
}

/// Which weight-for-stature indicator applies at this age.
GrowthIndicator weightForStatureIndicator(int ageDays) => isRecumbentExpected(
      ageDays,
    )
        ? GrowthIndicator.weightForLength
        : GrowthIndicator.weightForHeight;
