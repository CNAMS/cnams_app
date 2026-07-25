// WHO reference-table model and lookup. Pure Dart — no Flutter, no I/O.
//
// A table is a sorted list of (x -> L, M, S) points for one indicator and sex,
// where x is age in days (for -for-age indicators) or length/height in mm (for
// weight-for-length/height). Between tabulated points we interpolate L, M and S
// linearly. Outside the tabulated range the lookup returns null, so the engine
// can mark the result indeterminate rather than extrapolate off the standards.
//
// The tables themselves are loaded from bundled assets (see reference_data.dart)
// and injected into the engine, keeping this layer free of Flutter.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P2.

/// Biological sex; WHO growth references are sex-specific.
enum Sex { male, female }

/// The anthropometric indicators the engine computes.
enum GrowthIndicator {
  weightForAge,
  lengthOrHeightForAge,
  weightForLength,
  weightForHeight,
  muacForAge,
}

/// The three LMS parameters at a single point.
class Lms {
  const Lms(this.l, this.m, this.s);

  final double l;
  final double m;
  final double s;
}

/// One tabulated point: the key [x] (age in days, or length/height in mm) and
/// its LMS parameters.
class LmsPoint {
  const LmsPoint(this.x, this.lms);

  final double x;
  final Lms lms;
}

/// A single indicator/sex table. Points must be sorted ascending by x.
class LmsTable {
  LmsTable({
    required this.indicator,
    required this.sex,
    required this.points,
  });

  final GrowthIndicator indicator;
  final Sex sex;
  final List<LmsPoint> points;

  double get minX => points.first.x;
  double get maxX => points.last.x;

  /// LMS parameters at [x], linearly interpolated between bracketing points.
  /// Returns null if the table is empty or [x] is outside the tabulated range.
  Lms? at(double x) {
    if (points.isEmpty || x < points.first.x || x > points.last.x) {
      return null;
    }

    // Binary search for the last point with px <= x.
    var lo = 0;
    var hi = points.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (points[mid].x <= x) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }

    final left = points[lo];
    if (left.x == x || lo == points.length - 1) return left.lms;

    final right = points[lo + 1];
    final t = (x - left.x) / (right.x - left.x);
    return Lms(
      _lerp(left.lms.l, right.lms.l, t),
      _lerp(left.lms.m, right.lms.m, t),
      _lerp(left.lms.s, right.lms.s, t),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// The full set of reference tables, keyed by indicator and sex.
class ReferenceTables {
  ReferenceTables(List<LmsTable> tables)
      : _byKey = {for (final t in tables) (t.indicator, t.sex): t};

  final Map<(GrowthIndicator, Sex), LmsTable> _byKey;

  LmsTable? table(GrowthIndicator indicator, Sex sex) =>
      _byKey[(indicator, sex)];

  bool get isEmpty => _byKey.isEmpty;
}
