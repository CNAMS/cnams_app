// Referrals DAO: raise a referral and record its outcome on a later visit.
//
// The outcome is usually filled in days later when the family comes back, so
// creation and outcome are deliberately separate writes. Phase P5.

import 'package:drift/drift.dart';

import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/db/tables.dart';

part 'referrals_dao.g.dart';

@DriftAccessor(tables: [Referrals])
class ReferralsDao extends DatabaseAccessor<AppDatabase>
    with _$ReferralsDaoMixin {
  ReferralsDao(super.db);

  Future<void> create(ReferralsCompanion referral) =>
      into(referrals).insert(referral);

  /// Record the follow-up outcome ('attended' | 'not_attended' | 'unknown').
  Future<void> recordOutcome(String id, String outcome, DateTime when) {
    return (update(referrals)..where((r) => r.id.equals(id))).write(
      ReferralsCompanion(
        outcome: Value(outcome),
        outcomeRecordedAt: Value(when),
      ),
    );
  }

  /// Referrals still awaiting an outcome — the centre view's follow-up list.
  Future<List<Referral>> pending() {
    return (select(referrals)
          ..where((r) => r.outcome.equals('pending') | r.outcome.isNull()))
        .get();
  }
}
