// SyncService: drain the outbox one batch at a time.
//
// Pulls up to 50 oldest pending records, submits them, and applies the
// per-record outcome:
//   ok / conflict -> confirmed, removed from the outbox (a 409 means the server
//                    kept the superseded version under last-write-wins);
//   rejected (4xx) -> dead-lettered, kept for an operator but not retried;
//   retryLater / transport failure -> attempt count bumped so backoff applies.
//
// Nothing here touches the UI, and a record only leaves the outbox on an ok/
// conflict or an operator action — so a crash mid-batch can't lose data
// (FR-APP-13, CON-7, NFR-9).
//
// See docs/PRODUCTION_ROADMAP.md — Phase P4 §4.

import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/db/daos/outbox_dao.dart';
import 'package:cgms_app/core/sync/sync_api.dart';

/// Outcome counts from one drain pass.
class SyncSummary {
  const SyncSummary({
    this.confirmed = 0,
    this.conflicts = 0,
    this.deadLettered = 0,
    this.retryable = 0,
  });

  final int confirmed;
  final int conflicts;
  final int deadLettered;
  final int retryable;

  int get processed => confirmed + conflicts + deadLettered + retryable;
}

class SyncService {
  SyncService(this._db, this._api);

  final AppDatabase _db;
  final SyncApi _api;

  OutboxDao get _outbox => _db.outboxDao;

  /// Process one batch. Returns what happened. Safe to call repeatedly; call
  /// until [SyncSummary.processed] is 0 to fully drain.
  Future<SyncSummary> syncOnce() async {
    final rows = await _outbox.nextBatch();
    if (rows.isEmpty) return const SyncSummary();

    final records = [
      for (final r in rows)
        SyncRecord(
          outboxId: r.id,
          entity: r.entity,
          entityId: r.entityId,
          op: r.op,
          payload: r.payload,
        ),
    ];

    List<RecordResult> results;
    try {
      results = await _api.submit(records);
    } catch (_) {
      // Transport failure: the whole batch is retried later with backoff.
      for (final r in rows) {
        await _outbox.markFailed(r.id, r.attempts + 1, 'transport failure');
      }
      return SyncSummary(retryable: rows.length);
    }

    final byEntityId = {for (final r in results) r.entityId: r.status};

    var confirmed = 0, conflicts = 0, deadLettered = 0, retryable = 0;
    for (final row in rows) {
      // A record the server omitted is treated as retry-later, not lost.
      final status = byEntityId[row.entityId] ?? RecordStatus.retryLater;
      switch (status) {
        case RecordStatus.ok:
          await _outbox.confirm(row.id);
          confirmed++;
        case RecordStatus.conflict:
          await _outbox.confirm(row.id);
          conflicts++;
        case RecordStatus.rejected:
          await _outbox.markDeadLetter(row.id, 'rejected by server (4xx)');
          deadLettered++;
        case RecordStatus.retryLater:
          await _outbox.markFailed(row.id, row.attempts + 1, 'server 5xx');
          retryable++;
      }
    }

    return SyncSummary(
      confirmed: confirmed,
      conflicts: conflicts,
      deadLettered: deadLettered,
      retryable: retryable,
    );
  }

  /// Drain the outbox until nothing pending is left to process in a pass.
  /// Stops when a pass makes no progress (e.g. everything is backing off).
  Future<SyncSummary> drain({int maxPasses = 100}) async {
    var total = const SyncSummary();
    for (var i = 0; i < maxPasses; i++) {
      final pass = await syncOnce();
      total = SyncSummary(
        confirmed: total.confirmed + pass.confirmed,
        conflicts: total.conflicts + pass.conflicts,
        deadLettered: total.deadLettered + pass.deadLettered,
        retryable: total.retryable + pass.retryable,
      );
      // Stop if nothing was processed, or only retryable rows remain (they'd
      // just be reprocessed forever within one drain).
      if (pass.processed == 0 ||
          pass.confirmed + pass.conflicts + pass.deadLettered == 0) {
        break;
      }
    }
    return total;
  }
}
