// ChildRepository tests against an in-memory database.
//
// A fixed clock makes the overdue logic deterministic. Phase P1.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/data/child_repository.dart';
import 'package:cgms_app/core/db/app_database.dart';

void main() {
  late AppDatabase db;
  late ChildRepository repo;

  final now = DateTime.utc(2026, 7, 1, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.centres).insert(
          CentresCompanion.insert(id: 'centre-1', name: 'Centre 1'),
        );
    repo = ChildRepository(db, now: () => now);
  });

  tearDown(() => db.close());

  Future<String> register({
    String name = 'Aarav',
    ConsentStatus consent = ConsentStatus.given,
  }) {
    return repo.registerChild(
      centreId: 'centre-1',
      name: name,
      sex: ChildSex.male,
      dob: DateTime.utc(2024, 6, 1),
      dobPrecision: DobPrecision.month,
      consentStatus: consent,
      guardianName: 'Sita',
      consentRecordedAt: now,
    );
  }

  Future<void> addMeasurement(String childId, DateTime measuredAt) {
    return db.measurementsDao.insertMeasurement(
      MeasurementsCompanion.insert(
        id: 'm-$childId-${measuredAt.millisecondsSinceEpoch}',
        childId: childId,
        measuredAt: measuredAt,
        ageDays: 400,
        source: 'manual',
        engineVersion: 'test',
        appVersion: 'test',
        workerId: 'w1',
        createdAt: measuredAt,
        updatedAt: measuredAt,
      ),
    );
  }

  test('registering a child puts them on the roster and queues a sync',
      () async {
    final id = await register();

    final roster = await repo.watchRoster('centre-1').first;
    expect(roster, hasLength(1));
    expect(roster.single.child.id, id);
    expect(roster.single.child.consentStatus, 'given');
    expect(roster.single.child.dobPrecision, 'month');

    // A never-measured child is overdue.
    expect(roster.single.isOverdue, isTrue);
    expect(roster.single.lastMeasuredAt, isNull);

    // The write was queued for sync.
    final outbox = await db.select(db.outbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.entity, 'child');
    expect(outbox.single.op, 'upsert');
    expect(outbox.single.entityId, id);
  });

  test('a recent measurement clears the overdue flag', () async {
    final id = await register();
    await addMeasurement(id, now.subtract(const Duration(days: 3)));

    final roster = await repo.watchRoster('centre-1').first;
    expect(roster.single.isOverdue, isFalse);
    expect(roster.single.lastMeasuredAt, isNotNull);
  });

  test('an old measurement still counts as overdue', () async {
    final id = await register();
    await addMeasurement(id, now.subtract(const Duration(days: 45)));

    final roster = await repo.watchRoster('centre-1').first;
    expect(roster.single.isOverdue, isTrue);
  });

  test('withdrawing consent hides the child and queues a delete', () async {
    final id = await register();
    await repo.withdrawConsent(id);

    final roster = await repo.watchRoster('centre-1').first;
    expect(roster, isEmpty);

    final row = await repo.findById(id);
    expect(row, isNotNull);
    expect(row!.deleted, isTrue);
    expect(row.consentStatus, 'withdrawn');

    final ops = (await db.select(db.outbox).get()).map((o) => o.op).toList();
    expect(ops, containsAll(['upsert', 'delete']));
  });

  test('updating a child changes the stored fields', () async {
    final id = await register(name: 'Aarav');
    final child = await repo.findById(id);

    await repo.updateChild(child!, name: 'Aarav Kumar');

    final updated = await repo.findById(id);
    expect(updated!.name, 'Aarav Kumar');
  });

  test('roster is ordered by name, case-insensitively', () async {
    await register(name: 'zoya');
    await register(name: 'Aarav');

    final roster = await repo.watchRoster('centre-1').first;
    expect(roster.map((e) => e.child.name), ['Aarav', 'zoya']);
  });
}
