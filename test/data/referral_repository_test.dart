// ReferralRepository tests: raise, record outcome, per-child query, outbox.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/data/referral_repository.dart';
import 'package:cgms_app/core/db/app_database.dart';

void main() {
  late AppDatabase db;
  late ReferralRepository repo;
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
    await db.into(db.measurements).insert(
          MeasurementsCompanion.insert(
            id: 'm1',
            childId: 'child-1',
            measuredAt: now,
            ageDays: 400,
            source: 'manual',
            engineVersion: 'test',
            appVersion: 'test',
            workerId: 'w1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    repo = ReferralRepository(db, now: () => now);
  });

  tearDown(() => db.close());

  test('raise creates a pending referral and queues it', () async {
    final id = await repo.raise(
      measurementId: 'm1',
      referredTo: ReferredTo.nrc,
    );

    final row = await (db.select(db.referrals)..where((r) => r.id.equals(id)))
        .getSingle();
    expect(row.referredTo, 'NRC');
    expect(row.outcome, 'pending');

    final outbox = await db.select(db.outbox).get();
    expect(outbox.single.entity, 'referral');
  });

  test('recordOutcome updates the referral', () async {
    final id = await repo.raise(
      measurementId: 'm1',
      referredTo: ReferredTo.anm,
    );
    await repo.recordOutcome(id, ReferralOutcome.attended);

    final row = await (db.select(db.referrals)..where((r) => r.id.equals(id)))
        .getSingle();
    expect(row.outcome, 'attended');
    expect(row.outcomeRecordedAt, isNotNull);
  });

  test('watchForChild returns the child referrals, newest first', () async {
    await repo.raise(measurementId: 'm1', referredTo: ReferredTo.phc);
    final list = await repo.watchForChild('child-1').first;
    expect(list, hasLength(1));
    expect(list.single.referredTo, 'PHC');
  });

  test('outcome enum round-trips through the db string', () {
    expect(ReferralOutcome.notAttended.db, 'not_attended');
    expect(ReferralOutcome.fromDb('not_attended'), ReferralOutcome.notAttended);
    expect(ReferralOutcome.fromDb(null), ReferralOutcome.pending);
  });
}
