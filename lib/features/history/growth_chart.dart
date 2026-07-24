// Weight-for-age growth chart: the child's own trajectory over the WHO bands.
//
// Bands are drawn in grey (median a touch darker) when the reference tables are
// loaded; the child's measured weights sit on top as a coloured line with dots.
// Ages are shown in months. See docs/PRODUCTION_ROADMAP.md — Phase P3.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:cgms_app/features/history/growth_series.dart';

const double _daysPerMonth = 30.4375;

class GrowthChart extends StatelessWidget {
  const GrowthChart({
    required this.childPoints,
    required this.bands,
    required this.lineColor,
    super.key,
  });

  /// The child's measured points: x = age in days, y = weight in kg.
  final List<CurvePoint> childPoints;

  /// WHO bands (age-days keyed), or null when no table is loaded.
  final GrowthBands? bands;

  final Color lineColor;

  List<FlSpot> _spots(List<CurvePoint> pts) =>
      [for (final p in pts) FlSpot(p.x / _daysPerMonth, p.y)];

  LineChartBarData _bandBar(List<CurvePoint> pts, {required bool median}) {
    return LineChartBarData(
      spots: _spots(pts),
      isCurved: true,
      color: median ? Colors.grey.shade600 : Colors.grey.shade400,
      barWidth: median ? 1.5 : 1,
      dotData: const FlDotData(show: false),
      dashArray: median ? null : [6, 4],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bars = <LineChartBarData>[
      if (bands != null) ...[
        _bandBar(bands!.minus3, median: false),
        _bandBar(bands!.minus2, median: false),
        _bandBar(bands!.median, median: true),
        _bandBar(bands!.plus2, median: false),
        _bandBar(bands!.plus3, median: false),
      ],
      LineChartBarData(
        spots: _spots(childPoints),
        isCurved: false,
        color: lineColor,
        barWidth: 3,
        dotData: const FlDotData(show: true),
      ),
    ];

    return LineChart(
      LineChartData(
        lineBarsData: bars,
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(),
          rightTitles: AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 34),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(
          border: Border.all(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}
