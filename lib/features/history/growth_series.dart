// Growth-curve series. Pure Dart.
//
// Turns a WHO reference table into the band curves a growth chart draws — the
// median and the ±2 / ±3 SD lines — by inverting the LMS transform at each
// tabulated age. If no table is loaded (the WHO data hasn't been dropped in
// yet) this returns null and the chart simply shows the child's own trajectory.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P3.

import 'package:cgms_app/core/zscore/lms.dart';
import 'package:cgms_app/core/zscore/reference_tables.dart';

/// A single point on a curve: [x] is the table key (age in days or stature in
/// cm), [y] the measurement value (kg or cm).
class CurvePoint {
  const CurvePoint(this.x, this.y);
  final double x;
  final double y;
}

/// The WHO band curves for one indicator/sex table.
class GrowthBands {
  const GrowthBands({
    required this.minus3,
    required this.minus2,
    required this.median,
    required this.plus2,
    required this.plus3,
  });

  final List<CurvePoint> minus3;
  final List<CurvePoint> minus2;
  final List<CurvePoint> median;
  final List<CurvePoint> plus2;
  final List<CurvePoint> plus3;
}

/// Build band curves from [table], or null if there is nothing to draw.
GrowthBands? bandsFor(LmsTable? table) {
  if (table == null || table.points.isEmpty) return null;

  List<CurvePoint> line(double z) => [
        for (final p in table.points)
          CurvePoint(p.x, lmsValueAtZ(z, p.lms.l, p.lms.m, p.lms.s)),
      ];

  return GrowthBands(
    minus3: line(-3),
    minus2: line(-2),
    median: line(0),
    plus2: line(2),
    plus3: line(3),
  );
}
