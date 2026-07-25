// Outbox DAO: enqueue on write, pull a batch to sync, retire on success.
//
// The sync worker pulls oldest-first in batches of at most 50, then either
// deletes confirmed rows or bumps the attempt count with the last error. A row
// never disappears without either a server 200 or an operator clearing it, so a
// crash mid-sync can't lose data. Phase P4.

import 'package:drift/drift.dart';

import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/db/tables.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  static const int batchSize = 50;

  /// After this many failed attempts a row is a dead letter: it's kept for the
  /// record but no longer retried, and is surfaced in Settings for an operator.
  static const int maxAttempts = 8;

  Future<void> enqueue(OutboxCompanion entry) => into(outbox).insert(entry);

  /// Oldest-first batch to attempt next, excluding dead letters.
  Future<List<OutboxData>> nextBatch() {
    return (select(outbox)
          ..where((o) => o.attempts.isSmallerThanValue(maxAttempts))
          ..orderBy([(o) => OrderingTerm(expression: o.queuedAt)])
          ..limit(batchSize))
        .get();
  }

  /// Remove a row the server has confirmed (200).
  Future<void> confirm(int id) =>
      (delete(outbox)..where((o) => o.id.equals(id))).go();

  /// Record a failed attempt so backoff and the Settings backlog can reason
  /// about it.
  Future<void> markFailed(int id, int attempts, String error) {
    return (update(outbox)..where((o) => o.id.equals(id))).write(
      OutboxCompanion(attempts: Value(attempts), lastError: Value(error)),
    );
  }

  /// Force a row to dead-letter immediately (e.g. a permanent 4xx rejection).
  Future<void> markDeadLetter(int id, String error) =>
      markFailed(id, maxAttempts, error);

  Future<int> _countWhere(
      Expression<bool> Function($OutboxTable) filter) async {
    final count = countAll();
    final query = selectOnly(outbox)..addColumns([count]);
    query.where(filter(outbox));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Rows still waiting to sync (not yet dead-lettered) — the backlog badge.
  Future<int> pendingCount() =>
      _countWhere((o) => o.attempts.isSmallerThanValue(maxAttempts));

  /// Rows that have exhausted their retries — shown in Settings.
  Future<int> deadLetterCount() =>
      _countWhere((o) => o.attempts.isBiggerOrEqualValue(maxAttempts));
}
