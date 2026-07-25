// Loads WHO LMS reference tables from a bundled JSON asset and builds the
// pure-Dart ReferenceTables the engine consumes.
//
// This lives OUTSIDE core/zscore on purpose: reading an asset needs Flutter, and
// the engine layer must stay Flutter-free. Parsing itself is pure and testable
// with a plain string.
//
// Asset format (assets/who_reference/tables.json):
// {
//   "source": "…", "note": "…",
//   "tables": [
//     { "indicator": "weightForAge", "sex": "male",
//       "points": [ {"x": 0, "l": 0.3487, "m": 3.3464, "s": 0.14602}, … ] }
//   ]
// }
// x is age in days for -for-age indicators, or stature in cm for
// weightForLength/weightForHeight. l/m/s are the LMS parameters; m is in the
// indicator's natural unit (kg, cm).
//
// See docs/PRODUCTION_ROADMAP.md — Phase P2.

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'package:cgms_app/core/zscore/reference_tables.dart';

const String referenceAssetPath = 'assets/who_reference/tables.json';

/// Parse reference tables from a JSON string. Pure — no I/O.
ReferenceTables parseReferenceTables(String jsonStr) {
  final data = jsonDecode(jsonStr) as Map<String, dynamic>;
  final rawTables = (data['tables'] as List<dynamic>?) ?? const [];

  final tables = <LmsTable>[];
  for (final raw in rawTables) {
    final t = raw as Map<String, dynamic>;
    final rawPoints = t['points'] as List<dynamic>;
    final points = [
      for (final p in rawPoints)
        LmsPoint(
          (p['x'] as num).toDouble(),
          Lms(
            (p['l'] as num).toDouble(),
            (p['m'] as num).toDouble(),
            (p['s'] as num).toDouble(),
          ),
        ),
    ]..sort((a, b) => a.x.compareTo(b.x));

    if (points.isEmpty) continue;
    tables.add(
      LmsTable(
        indicator: _indicator(t['indicator'] as String),
        sex: t['sex'] == 'female' ? Sex.female : Sex.male,
        points: points,
      ),
    );
  }
  return ReferenceTables(tables);
}

/// Load and parse the bundled reference tables.
Future<ReferenceTables> loadReferenceTables([AssetBundle? bundle]) async {
  final jsonStr = await (bundle ?? rootBundle).loadString(referenceAssetPath);
  return parseReferenceTables(jsonStr);
}

GrowthIndicator _indicator(String name) =>
    GrowthIndicator.values.firstWhere((e) => e.name == name);
