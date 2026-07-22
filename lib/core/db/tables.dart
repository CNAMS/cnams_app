// drift table definitions mirroring lib/core/db/schema.sql.
//
// The schema is frozen at Gate G1. A few decisions here are deliberate and
// should not be "tidied up" later:
//   - every id is a client-generated UUIDv4 (TEXT), so records from different
//     phones never collide offline;
//   - Measurements.ageDays is stored, never recomputed, so a later DOB
//     correction can't silently rewrite a historical z-score;
//   - engineVersion/appVersion ride along on every measurement for audit;
//   - Children.deleted is a soft flag — hard deletes only go through the
//     consent-withdrawal path.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P0.

import 'package:drift/drift.dart';

/// Anganwadi centre the child is registered at.
class Centres extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icdsCode => text().nullable()();
  TextColumn get sector => text().nullable()();
  TextColumn get block => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A child on the roster.
class Children extends Table {
  TextColumn get id => text()();
  TextColumn get centreId => text().references(Centres, #id)();
  TextColumn get icdsId => text().nullable()();
  TextColumn get name => text()();

  /// 'M' | 'F'.
  TextColumn get sex => text().withLength(min: 1, max: 1)();

  DateTimeColumn get dob => dateTime()();

  /// 'exact' | 'month' | 'estimated' — rural DOBs are often approximate and
  /// that uncertainty must stay visible, not be hidden.
  TextColumn get dobPrecision => text()();

  TextColumn get guardianName => text().nullable()();

  /// 'none' | 'given' | 'withdrawn'.
  TextColumn get consentStatus => text()();
  DateTimeColumn get consentRecordedAt => dateTime().nullable()();

  /// Serial number of the paper consent form.
  TextColumn get consentFormRef => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A single measurement visit for a child.
class Measurements extends Table {
  TextColumn get id => text()();
  TextColumn get childId => text().references(Children, #id)();
  DateTimeColumn get measuredAt => dateTime()();

  /// Age in days at the moment of capture. STORED, never re-derived.
  IntColumn get ageDays => integer()();

  IntColumn get weightG => integer().nullable()();
  IntColumn get lengthMm => integer().nullable()();
  IntColumn get muacMm => integer().nullable()();

  /// 'recumbent' | 'standing'.
  TextColumn get position => text().nullable()();

  /// Clinical override: oedema forces SAM regardless of z-score (WHO rule).
  BoolColumn get oedema => boolean().withDefault(const Constant(false))();

  /// 'device' | 'manual'.
  TextColumn get source => text()();
  TextColumn get deviceSerial => text().nullable()();
  IntColumn get deviceSequence => integer().nullable()();

  RealColumn get waz => real().nullable()();
  RealColumn get haz => real().nullable()();
  RealColumn get whz => real().nullable()();
  RealColumn get maz => real().nullable()();

  /// 'normal' | 'mam' | 'sam' | 'overweight' | 'indeterminate'.
  TextColumn get classification => text().nullable()();

  /// JSON blob of plausibility/mode-mismatch flags.
  TextColumn get flags => text().nullable()();

  TextColumn get engineVersion => text()();
  TextColumn get appVersion => text()();
  TextColumn get workerId => text()();
  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A referral raised off a measurement, with follow-up outcome.
class Referrals extends Table {
  TextColumn get id => text()();
  TextColumn get measurementId => text().references(Measurements, #id)();

  /// 'ANM' | 'PHC' | 'NRC'.
  TextColumn get referredTo => text().nullable()();
  DateTimeColumn get referredAt => dateTime()();

  /// 'pending' | 'attended' | 'not_attended' | 'unknown'.
  TextColumn get outcome => text().nullable()();
  DateTimeColumn get outcomeRecordedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Durable sync queue. Rows leave only when the server confirms them or an
/// operator clears a dead letter — never dropped silently.
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 'child' | 'measurement' | 'referral'.
  TextColumn get entity => text()();
  TextColumn get entityId => text()();

  /// 'upsert' | 'delete'.
  TextColumn get op => text()();

  /// JSON snapshot of the record at enqueue time.
  TextColumn get payload => text()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get queuedAt => dateTime()();
}
