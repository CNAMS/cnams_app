// The WHO LMS z-score math. Pure Dart — no Flutter, no I/O.
//
// The LMS method models a skewed distribution with three age/sex-specific
// parameters: L (Box-Cox power), M (median), S (coefficient of variation). A
// measurement y maps to a z-score, and WHO applies a specific correction when
// |z| > 3 so extreme values stay on a sensible scale rather than exploding.
//
// References: WHO Child Growth Standards, "Computation of centiles and
// z-scores". The extreme-value adjustment is the one WHO Anthro uses.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P2.

import 'dart:math' as math;

/// Treat |L| below this as L == 0 (the logarithmic branch).
const double _lEpsilon = 1e-7;

/// The measurement value at a whole number of SDs from the median, for the
/// given L, M, S. This is the inverse of the LMS transform.
double lmsValueAtZ(double z, double l, double m, double s) {
  if (l.abs() < _lEpsilon) {
    return m * math.exp(s * z);
  }
  return m * math.pow(1 + l * s * z, 1 / l).toDouble();
}

/// Z-score of measurement [y] under the LMS parameters [l], [m], [s].
///
/// For |z| > 3 the value is rescaled using the distance between the ±2 and ±3
/// SD cut-offs, per WHO — otherwise the Box-Cox tail distorts extreme scores.
double lmsZScore(double y, double l, double m, double s) {
  final double z;
  if (l.abs() < _lEpsilon) {
    z = math.log(y / m) / s;
  } else {
    z = (math.pow(y / m, l).toDouble() - 1) / (l * s);
  }

  if (z > 3) {
    final sd3 = lmsValueAtZ(3, l, m, s);
    final sd2 = lmsValueAtZ(2, l, m, s);
    return 3 + (y - sd3) / (sd3 - sd2);
  }
  if (z < -3) {
    final sd3 = lmsValueAtZ(-3, l, m, s);
    final sd2 = lmsValueAtZ(-2, l, m, s);
    return -3 + (y - sd3) / (sd2 - sd3);
  }
  return z;
}
