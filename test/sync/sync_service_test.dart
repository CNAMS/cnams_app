// SyncService tests against an in-memory outbox and a fake API.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/db/daos/outbox_dao.dart';
import 'package:cgms_app/core/sync/sync_api.dart';
import 'package:cgms_app/core/sync/sync_service.dart';

/// Fake API returning a preset status per entity id, or throwing to simulate a
/// transport failure. Records every batch it received.
class FakeSyncApi implements SyncApi {
  FakeSyncApi(this.statusFor, {this.throwOnce = false});

  final RecordStatus Function(String entityId) statusFor;
  bool throwOnce;
  final List<List<SyncRecord>> batches = [];

  @override
  Future<List<RecordResult>> submit(List<SyncRecord> records) async {
    batches.add(records);
    if (throwOnce) {
      throwOnce = false;
      throw Exception('network down');
    }
    return [
      for (final r in records) RecordResult(r.entityId, statusFor(r.entityId)),
    ];
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> enqueue(String entityId, {String op = 'upsert'}) {
    return db.outboxDao.enqueue(
      OutboxCompanion.insert(
        entity: 'measurement',
        entityId: entityId,
        op: op,
        payload: '{"id":"$entityId"}',
        queuedAt: DateTime.utc(2026, 7, 1),
      ),
    );
  }

  test('confirmed records are removed from the outbox', () async {
    await enqueue('a');
    await enqueue('b');
    final service = SyncService(db, FakeSyncApi((_) => RecordStatus.ok));

    final summary = await service.syncOnce();

    expect(summary.confirmed, 2);
    expect(await db.outboxDao.pendingCount(), 0);
  });

  test('a 409 conflict also clears the record (last-write-wins)', () async {
    await enqueue('a');
    final service = SyncService(db, FakeSyncApi((_) => RecordStatus.conflict));

    final summary = await service.syncOnce();

    expect(summary.conflicts, 1);
    expect(await db.outboxDao.pendingCount(), 0);
  });

  test('a 4xx rejection dead-letters the record', () async {
    await enqueue('a');
    final service = SyncService(db, FakeSyncApi((_) => RecordStatus.rejected));

    final summary = await service.syncOnce();

    expect(summary.deadLettered, 1);
    expect(await db.outboxDao.pendingCount(), 0); // no longer pending
    expect(await db.outboxDao.deadLetterCount(), 1);
  });

  test('a transport failure keeps records and bumps their attempts', () async {
    await enqueue('a');
    final service =
        SyncService(db, FakeSyncApi((_) => RecordStatus.ok, throwOnce: true));

    final summary = await service.syncOnce();

    expect(summary.retryable, 1);
    expect(await db.outboxDao.pendingCount(), 1); // still pending
    final row = await db.select(db.outbox).getSingle();
    expect(row.attempts, 1);
    expect(row.lastError, contains('transport'));
  });

  test('records keep their UUID as the idempotency key', () async {
    await enqueue('child-123');
    final api = FakeSyncApi((_) => RecordStatus.ok);
    await SyncService(db, api).syncOnce();
    expect(api.batches.single.single.entityId, 'child-123');
  });

  test('one pass processes at most a batch; drain empties everything',
      () async {
    for (var i = 0; i < 120; i++) {
      await enqueue('r$i');
    }
    final service = SyncService(db, FakeSyncApi((_) => RecordStatus.ok));

    final first = await service.syncOnce();
    expect(first.confirmed, OutboxDao.batchSize); // capped at 50

    final rest = await service.drain();
    expect(rest.confirmed, 120 - OutboxDao.batchSize);
    expect(await db.outboxDao.pendingCount(), 0);
  });
}
