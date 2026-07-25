// Child repository: the app's one door to child records.
//
// Screens talk to this, never to the DAOs directly. Writes go to the database
// AND enqueue an outbox entry in the same transaction, so an offline write is
// durable and will sync later (the worker that drains the outbox is Phase P4).
//
// See docs/PRODUCTION_ROADMAP.md — Phase P1.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:cgms_app/core/db/app_database.dart';

/// A child's biological sex as recorded (WHO references are sex-specific).
enum ChildSex {
  male,
  female;

  String get db => this == ChildSex.male ? 'M' : 'F';

  static ChildSex fromDb(String v) =>
      v == 'M' ? ChildSex.male : ChildSex.female;
}

/// How precisely the date of birth is known. Rural DOBs are often approximate
/// and that uncertainty must stay visible, never be hidden.
enum DobPrecision {
  exact,
  month,
  estimated;

  String get db => name;

  static DobPrecision fromDb(String v) =>
      DobPrecision.values.firstWhere((e) => e.name == v);
}

/// Consent state for a child's participation.
enum ConsentStatus {
  none,
  given,
  withdrawn;

  String get db => name;

  static ConsentStatus fromDb(String v) =>
      ConsentStatus.values.firstWhere((e) => e.name == v);
}

/// A roster row: the child plus when they were last measured and whether that
/// makes them overdue. Immutable view model — screens render this, not raw rows.
class RosterEntry {
  const RosterEntry({
    required this.child,
    required this.lastMeasuredAt,
    required this.isOverdue,
  });

  final Child child;
  final DateTime? lastMeasuredAt;
  final bool isOverdue;
}

class ChildRepository {
  ChildRepository(
    this._db, {
    Uuid uuid = const Uuid(),
    DateTime Function() now = DateTime.now,
  })  : _uuid = uuid,
        _now = now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// A child with no measurement in this window is due for one.
  static const Duration overdueAfter = Duration(days: 30);

  bool _isOverdue(DateTime? last) =>
      last == null || _now().difference(last) > overdueAfter;

  /// Live roster for a centre, ordered by name, each row annotated with its
  /// last-measured date and overdue flag. Re-emits when either children or
  /// measurements change.
  Stream<List<RosterEntry>> watchRoster(String centreId) {
    final query = _db.customSelect(
      'SELECT c.*, '
      '(SELECT MAX(m.measured_at) FROM measurements m WHERE m.child_id = c.id) '
      'AS last_measured_at '
      'FROM children c '
      'WHERE c.centre_id = ?1 AND c.deleted = 0 '
      'ORDER BY LOWER(c.name)',
      variables: [Variable<String>(centreId)],
      readsFrom: {_db.children, _db.measurements},
    );
    return query.watch().map(
          (rows) => rows.map(_toEntry).toList(growable: false),
        );
  }

  RosterEntry _toEntry(QueryRow row) {
    final child = _db.children.map(row.data);
    final last = row.readNullable<DateTime>('last_measured_at');
    return RosterEntry(
      child: child,
      lastMeasuredAt: last,
      isOverdue: _isOverdue(last),
    );
  }

  Future<Child?> findById(String id) => _db.childrenDao.findById(id);

  /// Register a new child and queue it for sync. Returns the new id.
  Future<String> registerChild({
    required String centreId,
    required String name,
    required ChildSex sex,
    required DateTime dob,
    required DobPrecision dobPrecision,
    required ConsentStatus consentStatus,
    String? guardianName,
    String? icdsId,
    String? consentFormRef,
    DateTime? consentRecordedAt,
  }) async {
    final id = _uuid.v4();
    final now = _now();
    final companion = ChildrenCompanion.insert(
      id: id,
      centreId: centreId,
      name: name,
      sex: sex.db,
      dob: dob,
      dobPrecision: dobPrecision.db,
      consentStatus: consentStatus.db,
      createdAt: now,
      updatedAt: now,
      guardianName: Value(guardianName),
      icdsId: Value(icdsId),
      consentFormRef: Value(consentFormRef),
      consentRecordedAt: Value(consentRecordedAt),
    );

    await _db.transaction(() async {
      await _db.childrenDao.upsert(companion);
      await _enqueue('child', id, 'upsert', {
        'id': id,
        'centre_id': centreId,
        'name': name,
        'sex': sex.db,
        'dob': dob.toIso8601String(),
        'dob_precision': dobPrecision.db,
        'guardian_name': guardianName,
        'icds_id': icdsId,
        'consent_status': consentStatus.db,
      });
    });
    return id;
  }

  /// Edit an existing child. [current] is the row being edited; only the fields
  /// passed are changed.
  Future<void> updateChild(
    Child current, {
    String? name,
    ChildSex? sex,
    DateTime? dob,
    DobPrecision? dobPrecision,
    String? guardianName,
    String? icdsId,
    ConsentStatus? consentStatus,
    String? consentFormRef,
    DateTime? consentRecordedAt,
  }) async {
    final now = _now();
    final updated = current.copyWith(
      name: name ?? current.name,
      sex: sex?.db ?? current.sex,
      dob: dob ?? current.dob,
      dobPrecision: dobPrecision?.db ?? current.dobPrecision,
      guardianName: Value(guardianName ?? current.guardianName),
      icdsId: Value(icdsId ?? current.icdsId),
      consentStatus: consentStatus?.db ?? current.consentStatus,
      consentFormRef: Value(consentFormRef ?? current.consentFormRef),
      consentRecordedAt: Value(consentRecordedAt ?? current.consentRecordedAt),
      updatedAt: now,
    );

    await _db.transaction(() async {
      await _db.childrenDao.upsert(updated.toCompanion(false));
      await _enqueue('child', current.id, 'upsert', {'id': current.id});
    });
  }

  /// Consent-withdrawal path: mark consent withdrawn, soft-delete locally, and
  /// queue a delete so the server mirrors the removal. Hard deletion only ever
  /// happens through here.
  Future<void> withdrawConsent(String childId) async {
    final now = _now();
    await _db.transaction(() async {
      await (_db.update(_db.children)..where((c) => c.id.equals(childId)))
          .write(
        ChildrenCompanion(
          consentStatus: Value(ConsentStatus.withdrawn.db),
          consentRecordedAt: Value(now),
          deleted: const Value(true),
          updatedAt: Value(now),
        ),
      );
      await _enqueue('child', childId, 'delete', {'id': childId});
    });
  }

  Future<void> _enqueue(
    String entity,
    String entityId,
    String op,
    Map<String, dynamic> payload,
  ) {
    return _db.outboxDao.enqueue(
      OutboxCompanion.insert(
        entity: entity,
        entityId: entityId,
        op: op,
        payload: jsonEncode(payload),
        queuedAt: _now(),
      ),
    );
  }
}
