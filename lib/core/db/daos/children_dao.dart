// Children DAO: create / update / soft-delete / search.
//
// Roster reads exclude soft-deleted rows and order by name so the list an AWW
// scrolls stays stable. Search matches name or guardian so a worker can find a
// child by whoever brought them in. Phase P1.

import 'package:drift/drift.dart';

import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/db/tables.dart';

part 'children_dao.g.dart';

@DriftAccessor(tables: [Children])
class ChildrenDao extends DatabaseAccessor<AppDatabase>
    with _$ChildrenDaoMixin {
  ChildrenDao(super.db);

  /// Insert or replace a child row.
  Future<void> upsert(ChildrenCompanion child) =>
      into(children).insertOnConflictUpdate(child);

  /// Live roster for a centre, ordered by name so the list doesn't jump around
  /// under the worker's finger. Excludes soft-deleted rows.
  Stream<List<Child>> watchRoster(String centreId) {
    return (select(children)
          ..where((c) => c.centreId.equals(centreId) & c.deleted.equals(false))
          ..orderBy([(c) => OrderingTerm(expression: c.name)]))
        .watch();
  }

  /// Case-insensitive search over name and guardian within a centre.
  Future<List<Child>> search(String centreId, String query) {
    final like = '%${query.toLowerCase()}%';
    return (select(children)
          ..where(
            (c) =>
                c.centreId.equals(centreId) &
                c.deleted.equals(false) &
                (c.name.lower().like(like) | c.guardianName.lower().like(like)),
          ))
        .get();
  }

  Future<Child?> findById(String id) =>
      (select(children)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// Soft delete — the row stays for audit/sync. A hard delete only happens on
  /// the consent-withdrawal path.
  Future<void> softDelete(String id, DateTime now) {
    return (update(children)..where((c) => c.id.equals(id))).write(
      ChildrenCompanion(deleted: const Value(true), updatedAt: Value(now)),
    );
  }
}
