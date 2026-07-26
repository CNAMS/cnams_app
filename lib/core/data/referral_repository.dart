// Referral repository (R1 / FR-APP-9): raise a referral off a measurement and
// record its outcome on a later visit. Like the other repositories, every write
// also enqueues an outbox entry in the same transaction.
//
// See docs/REFINEMENT_ROADMAP.md — R1.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:cgms_app/core/db/app_database.dart';

/// Where a child is referred.
enum ReferredTo {
  anm,
  phc,
  nrc;

  String get db => name.toUpperCase(); // 'ANM' | 'PHC' | 'NRC'
}

/// Referral follow-up outcome.
enum ReferralOutcome {
  pending,
  attended,
  notAttended,
  unknown;

  String get db => switch (this) {
        ReferralOutcome.pending => 'pending',
        ReferralOutcome.attended => 'attended',
        ReferralOutcome.notAttended => 'not_attended',
        ReferralOutcome.unknown => 'unknown',
      };

  static ReferralOutcome fromDb(String? v) => switch (v) {
        'attended' => ReferralOutcome.attended,
        'not_attended' => ReferralOutcome.notAttended,
        'unknown' => ReferralOutcome.unknown,
        _ => ReferralOutcome.pending,
      };
}

class ReferralRepository {
  ReferralRepository(
    this._db, {
    Uuid uuid = const Uuid(),
    DateTime Function() now = DateTime.now,
  })  : _uuid = uuid,
        _now = now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// Raise a referral for a measurement. Returns the new id.
  Future<String> raise({
    required String measurementId,
    required ReferredTo referredTo,
  }) async {
    final id = _uuid.v4();
    final now = _now();
    await _db.transaction(() async {
      await _db.referralsDao.create(
        ReferralsCompanion.insert(
          id: id,
          measurementId: measurementId,
          referredAt: now,
          referredTo: Value(referredTo.db),
          outcome: const Value('pending'),
        ),
      );
      await _enqueue(id, {
        'id': id,
        'measurement_id': measurementId,
        'referred_to': referredTo.db,
        'outcome': 'pending',
      });
    });
    return id;
  }

  /// Record the follow-up outcome on a later visit.
  Future<void> recordOutcome(String id, ReferralOutcome outcome) async {
    await _db.transaction(() async {
      await _db.referralsDao.recordOutcome(id, outcome.db, _now());
      await _enqueue(id, {'id': id, 'outcome': outcome.db});
    });
  }

  /// A child's referrals, newest first (joined via their measurements).
  Stream<List<Referral>> watchForChild(String childId) {
    final query = _db.select(_db.referrals).join([
      innerJoin(
        _db.measurements,
        _db.measurements.id.equalsExp(_db.referrals.measurementId),
      ),
    ])
      ..where(_db.measurements.childId.equals(childId))
      ..orderBy([
        OrderingTerm(
          expression: _db.referrals.referredAt,
          mode: OrderingMode.desc,
        ),
      ]);
    return query.watch().map(
          (rows) => rows.map((r) => r.readTable(_db.referrals)).toList(),
        );
  }

  Future<void> _enqueue(String id, Map<String, dynamic> payload) {
    return _db.outboxDao.enqueue(
      OutboxCompanion.insert(
        entity: 'referral',
        entityId: id,
        op: 'upsert',
        payload: jsonEncode(payload),
        queuedAt: _now(),
      ),
    );
  }
}
