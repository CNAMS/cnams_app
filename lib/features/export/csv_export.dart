// CSV export of measurements (FR-APP-12). Pure Dart — testable byte-for-byte.
//
// Column order matches the Poshan Tracker import layout so a supervisor can
// upload the file directly. The order below is the working definition; it must
// be confirmed with an AWW before Gate G4 (that sign-off is the DoD, not this
// code). Keep [poshanTrackerColumns] and [_cells] in lockstep.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P4.

import 'package:cgms_app/core/db/app_database.dart';

/// One measurement joined with its child, ready to export.
class ExportRow {
  const ExportRow({required this.child, required this.measurement});
  final Child child;
  final Measurement measurement;
}

/// Header row, in Poshan Tracker column order (pending AWW confirmation).
const List<String> poshanTrackerColumns = [
  'icds_id',
  'child_name',
  'sex',
  'dob',
  'age_days',
  'measured_at',
  'weight_kg',
  'length_cm',
  'muac_cm',
  'oedema',
  'waz',
  'haz',
  'whz',
  'classification',
];

/// Build the CSV text for [rows].
String buildMeasurementCsv(Iterable<ExportRow> rows) {
  final buffer = StringBuffer()..writeln(_line(poshanTrackerColumns));
  for (final row in rows) {
    buffer.writeln(_line(_cells(row)));
  }
  return buffer.toString();
}

List<String> _cells(ExportRow row) {
  final c = row.child;
  final m = row.measurement;
  return [
    c.icdsId ?? '',
    c.name,
    c.sex,
    _date(c.dob),
    '${m.ageDays}',
    _dateTime(m.measuredAt),
    _fixed(m.weightG, 1000, 2),
    _fixed(m.lengthMm, 10, 1),
    _fixed(m.muacMm, 10, 1),
    m.oedema ? '1' : '0',
    _num(m.waz),
    _num(m.haz),
    _num(m.whz),
    m.classification ?? '',
  ];
}

String _line(List<String> cells) => cells.map(_escape).join(',');

/// RFC-4180 quoting: wrap in quotes and double any embedded quotes when the
/// value contains a comma, quote, or newline.
String _escape(String value) {
  if (value.contains(RegExp('[",\n\r]'))) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String _fixed(int? raw, int divisor, int digits) =>
    raw == null ? '' : (raw / divisor).toStringAsFixed(digits);

String _num(double? z) => z == null ? '' : z.toStringAsFixed(2);

String _date(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

String _dateTime(DateTime d) => '${_date(d)} ${_two(d.hour)}:${_two(d.minute)}';

String _two(int n) => n.toString().padLeft(2, '0');
