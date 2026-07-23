// MeasurementRepository tests: persistence of the row + result, and outbox
// queueing, against an in-memory database.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/data/measurement_repository.dart';
import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/core/zscore/zscore_engine.dart';

void main() {
  late AppDatabase db;
  late MeasurementRepository repo;
  final now = DateTime.utc(2026, 7, 1);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.centres).insert(
          CentresCompanion.insert(id: 'c1', name: 'Centre'),
        );
    await db.into(db.children).insert(
          ChildrenCompanion.insert(
            id: 'child-1',
            centreId: 'c1',
            name: 'Aarav',
            sex: 'M',
            dob: DateTime.utc(2024, 6, 1),
            dobPrecision: 'exact',
            consentStatus: 'given',
            createdAt: now,
            updatedAt: now,
          ),
        );
    repo = MeasurementRepository(db, now: () => now);
  });

  tearDown(() => db.close());

  test('saves a measurement with its result and queues it to sync', () async {
    const result = ZScoreResult(
      whz: -3.4,
      classification: GrowthClass.sam,
      engineVersion: '1.0.0-lms',
      flags: ['position_corrected'],
    );

    final id = await repo.save(
      childId: 'child-1',
      ageDays: 400,
      result: result,
      workerId: 'w1',
      appVersion: '0.1.0',
      weightG: 7000,
      lengthMm: 800,
      muacMm: 118,
      recumbent: true,
      source: 'device',
      deviceSerial: 'MOCK-0001',
    );

    final row = await (db.select(db.measurements)
          ..where((m) => m.id.equals(id)))
        .getSingle();
    expect(row.childId, 'child-1');
    expect(row.classification, 'sam');
    expect(row.whz, closeTo(-3.4, 1e-9));
    expect(row.ageDays, 400); // stored, not recomputed
    expect(row.engineVersion, '1.0.0-lms');
    expect(row.flags, contains('position_corrected'));

    final outbox = await db.select(db.outbox).get();
    expect(outbox.single.entity, 'measurement');
    expect(outbox.single.op, 'upsert');
  });
}
