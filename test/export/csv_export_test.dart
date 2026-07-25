// CSV export tests: header order, cell formatting, and RFC-4180 escaping.

import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/features/export/csv_export.dart';

Child _child({String name = 'Aarav', String? icds = 'ICDS-1'}) {
  final t = DateTime.utc(2026, 1, 1);
  return Child(
    id: 'c1',
    centreId: 'centre',
    icdsId: icds,
    name: name,
    sex: 'M',
    dob: DateTime.utc(2024, 6, 1),
    dobPrecision: 'exact',
    consentStatus: 'given',
    createdAt: t,
    updatedAt: t,
    deleted: false,
  );
}

Measurement _measurement() {
  return Measurement(
    id: 'm1',
    childId: 'c1',
    measuredAt: DateTime.utc(2026, 6, 1, 9, 5),
    ageDays: 730,
    oedema: false,
    source: 'device',
    engineVersion: '1.0.0-lms',
    appVersion: '0.1.0',
    workerId: 'w1',
    createdAt: DateTime.utc(2026, 6, 1),
    updatedAt: DateTime.utc(2026, 6, 1),
    weightG: 9500,
    lengthMm: 820,
    muacMm: 135,
    waz: -1.23,
    whz: -0.5,
    classification: 'normal',
  );
}

void main() {
  test('first line is the header in Poshan Tracker order', () {
    final csv = buildMeasurementCsv([]);
    expect(csv.trim(), poshanTrackerColumns.join(','));
  });

  test('formats a row with unit conversions and fixed precision', () {
    final csv = buildMeasurementCsv([
      ExportRow(child: _child(), measurement: _measurement()),
    ]);
    final row = csv.trim().split('\n')[1];
    expect(
      row,
      'ICDS-1,Aarav,M,2024-06-01,730,2026-06-01 09:05,9.50,82.0,13.5,0,-1.23,,-0.50,normal',
    );
  });

  test('escapes a name containing a comma', () {
    final csv = buildMeasurementCsv([
      ExportRow(
        child: _child(name: 'Kumar, Aarav'),
        measurement: _measurement(),
      ),
    ]);
    expect(csv, contains('"Kumar, Aarav"'));
  });

  test('empty optional fields render as empty cells', () {
    final csv = buildMeasurementCsv([
      ExportRow(child: _child(icds: null), measurement: _measurement()),
    ]);
    // Leading comma: empty icds_id then the name.
    expect(csv.trim().split('\n')[1].startsWith(',Aarav,'), isTrue);
  });
}
