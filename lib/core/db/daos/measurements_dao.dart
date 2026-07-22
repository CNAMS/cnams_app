// Measurements DAO: insert and read a child's growth history.
//
// Rows are immutable once written in spirit — a re-measure is a new row, not an
// edit — so history and z-score provenance stay intact. Phase P2.

import 'package:drift/drift.dart';

import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/db/tables.dart';

part 'measurements_dao.g.dart';

@DriftAccessor(tables: [Measurements])
class MeasurementsDao extends DatabaseAccessor<AppDatabase>
    with _$MeasurementsDaoMixin {
  MeasurementsDao(super.db);

  Future<void> insertMeasurement(MeasurementsCompanion m) =>
      into(measurements).insert(m);

  /// A child's visits, newest first — this is what the growth curve reads.
  Stream<List<Measurement>> watchForChild(String childId) {
    return (select(measurements)
          ..where((m) => m.childId.equals(childId))
          ..orderBy([
            (m) => OrderingTerm(
                  expression: m.measuredAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  Future<Measurement?> latestForChild(String childId) {
    return (select(measurements)
          ..where((m) => m.childId.equals(childId))
          ..orderBy([
            (m) => OrderingTerm(
                  expression: m.measuredAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }
}
