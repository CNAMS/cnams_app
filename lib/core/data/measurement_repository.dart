// Measurement repository: persist a completed measurement and queue it to sync.
//
// Mirrors ChildRepository — one write path, DB plus outbox in a single
// transaction, so a capture done offline is durable. The engine's outputs
// (z-scores, classification, engine version, flags) are stored on the row so a
// historical result is reproducible even after the engine is later revised.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P2.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/zscore/zscore_engine.dart';

class MeasurementRepository {
  MeasurementRepository(
    this._db, {
    Uuid uuid = const Uuid(),
    DateTime Function() now = DateTime.now,
  })  : _uuid = uuid,
        _now = now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// Persist a measurement plus its computed result. Returns the new id.
  Future<String> save({
    required String childId,
    required int ageDays,
    required ZScoreResult result,
    required String workerId,
    required String appVersion,
    int? weightG,
    int? lengthMm,
    int? muacMm,
    bool recumbent = true,
    bool oedema = false,
    required String source, // 'device' | 'manual'
    String? deviceSerial,
    int? deviceSequence,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final now = _now();

    final companion = MeasurementsCompanion.insert(
      id: id,
      childId: childId,
      measuredAt: now,
      ageDays: ageDays,
      source: source,
      engineVersion: result.engineVersion,
      appVersion: appVersion,
      workerId: workerId,
      createdAt: now,
      updatedAt: now,
      weightG: Value(weightG),
      lengthMm: Value(lengthMm),
      muacMm: Value(muacMm),
      position: Value(recumbent ? 'recumbent' : 'standing'),
      oedema: Value(oedema),
      deviceSerial: Value(deviceSerial),
      deviceSequence: Value(deviceSequence),
      waz: Value(result.waz),
      haz: Value(result.haz),
      whz: Value(result.whz),
      maz: Value(result.maz),
      classification: Value(result.classification.name),
      flags: Value(result.flags.isEmpty ? null : jsonEncode(result.flags)),
      notes: Value(notes),
    );

    await _db.transaction(() async {
      await _db.measurementsDao.insertMeasurement(companion);
      await _db.outboxDao.enqueue(
        OutboxCompanion.insert(
          entity: 'measurement',
          entityId: id,
          op: 'upsert',
          payload: jsonEncode({
            'id': id,
            'child_id': childId,
            'age_days': ageDays,
            'weight_g': weightG,
            'length_mm': lengthMm,
            'muac_mm': muacMm,
            'classification': result.classification.name,
          }),
          queuedAt: now,
        ),
      );
    });
    return id;
  }

  Stream<List<Measurement>> watchForChild(String childId) =>
      _db.measurementsDao.watchForChild(childId);

  /// All measurements in a centre, each paired with its child, oldest first —
  /// the source rows for CSV export. Returns records rather than a feature type
  /// so this stays in the core layer.
  Future<List<(Child, Measurement)>> measurementsWithChildren(
    String centreId,
  ) async {
    final query = _db.select(_db.measurements).join([
      innerJoin(
        _db.children,
        _db.children.id.equalsExp(_db.measurements.childId),
      ),
    ])
      ..where(_db.children.centreId.equals(centreId))
      ..orderBy([OrderingTerm(expression: _db.measurements.measuredAt)]);

    final rows = await query.get();
    return [
      for (final r in rows)
        (r.readTable(_db.children), r.readTable(_db.measurements)),
    ];
  }
}
