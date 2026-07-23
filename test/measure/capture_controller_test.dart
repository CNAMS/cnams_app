// CaptureController tests: age derivation, the oedema override, and that a save
// persists the computed result.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/data/measurement_repository.dart';
import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/core/zscore/reference_tables.dart';
import 'package:cgms_app/core/zscore/who_lms_engine.dart';
import 'package:cgms_app/features/measure/capture_controller.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 7, 1);
  // 365 days old at capture time.
  final child = Child(
    id: 'child-1',
    centreId: 'c1',
    name: 'Aarav',
    sex: 'M',
    dob: DateTime.utc(2025, 7, 1),
    dobPrecision: 'exact',
    consentStatus: 'given',
    createdAt: now,
    updatedAt: now,
    deleted: false,
  );

  CaptureController controller() => CaptureController(
        child: child,
        engine: WhoLmsEngine(ReferenceTables(const [])),
        repository: MeasurementRepository(db, now: () => now),
        workerId: 'w1',
        appVersion: '0.1.0',
        deviceSerial: 'MOCK-0001',
        now: () => now,
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.centres).insert(
          CentresCompanion.insert(id: 'c1', name: 'Centre'),
        );
    await db.into(db.children).insert(child.toCompanion(false));
  });

  tearDown(() => db.close());

  test('derives age in days and the expected measurement position', () {
    final c = controller();
    expect(c.state.ageDays, 365);
    expect(c.recumbentExpected, isTrue); // under 24 months
  });

  test('oedema forces a SAM result', () {
    final c = controller()
      ..setWeight(9000)
      ..setLength(750, recumbent: true)
      ..setOedema(true);
    final result = c.computeResult();
    expect(result.classification, GrowthClass.sam);
    expect(c.state.result, isNotNull);
  });

  test('save persists the measurement and its classification', () async {
    final c = controller()
      ..setWeight(9000)
      ..setLength(750, recumbent: true)
      ..setMuac(110); // < 115 mm -> SAM even with empty reference tables

    final id = await c.save();

    final row = await (db.select(db.measurements)
          ..where((m) => m.id.equals(id)))
        .getSingle();
    expect(row.childId, 'child-1');
    expect(row.ageDays, 365);
    expect(row.classification, 'sam');
    expect(row.source, 'device');
    expect(row.deviceSerial, 'MOCK-0001');
  });
}
