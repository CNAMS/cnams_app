// Children DAO tests against an in-memory database.
//
// These run headless (no Flutter binding needed) because the DB layer is pure
// Dart over drift's NativeDatabase.memory(). Phase P1.

// drift also exports isNull/isNotNull as SQL expression helpers; hide them so
// the matcher versions win in the test body.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/db/app_database.dart';

AppDatabase _memoryDb() => AppDatabase(NativeDatabase.memory());

ChildrenCompanion _child({
  required String id,
  required String centreId,
  String name = 'Aarav',
  String? guardian = 'Sita',
  bool deleted = false,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return ChildrenCompanion.insert(
    id: id,
    centreId: centreId,
    name: name,
    sex: 'M',
    dob: DateTime.utc(2024, 6, 1),
    dobPrecision: 'exact',
    consentStatus: 'given',
    createdAt: now,
    updatedAt: now,
    guardianName: Value(guardian),
    deleted: Value(deleted),
  );
}

Future<void> _seedCentre(AppDatabase db, String id) {
  return db.into(db.centres).insert(
        CentresCompanion.insert(id: id, name: 'Centre $id'),
      );
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = _memoryDb();
    await _seedCentre(db, 'centre-1');
  });

  tearDown(() => db.close());

  test('upsert then findById round-trips a child', () async {
    await db.childrenDao.upsert(_child(id: 'c1', centreId: 'centre-1'));

    final found = await db.childrenDao.findById('c1');
    expect(found, isNotNull);
    expect(found!.name, 'Aarav');
    expect(found.consentStatus, 'given');
  });

  test('soft delete hides the child from the roster but keeps the row',
      () async {
    await db.childrenDao.upsert(_child(id: 'c1', centreId: 'centre-1'));
    await db.childrenDao.softDelete('c1', DateTime.utc(2026, 2, 1));

    final roster = await db.childrenDao.watchRoster('centre-1').first;
    expect(roster, isEmpty);

    final stillThere = await db.childrenDao.findById('c1');
    expect(stillThere, isNotNull);
    expect(stillThere!.deleted, isTrue);
  });

  test('search matches on name or guardian, case-insensitively', () async {
    await db.childrenDao.upsert(
      _child(id: 'c1', centreId: 'centre-1', name: 'Aarav', guardian: 'Sita'),
    );
    await db.childrenDao.upsert(
      _child(id: 'c2', centreId: 'centre-1', name: 'Diya', guardian: 'Ram'),
    );

    final byName = await db.childrenDao.search('centre-1', 'aar');
    expect(byName.map((c) => c.id), ['c1']);

    final byGuardian = await db.childrenDao.search('centre-1', 'RAM');
    expect(byGuardian.map((c) => c.id), ['c2']);
  });

  test('roster is ordered by name', () async {
    await db.childrenDao
        .upsert(_child(id: 'c1', centreId: 'centre-1', name: 'Zoya'));
    await db.childrenDao
        .upsert(_child(id: 'c2', centreId: 'centre-1', name: 'Aarav'));

    final roster = await db.childrenDao.watchRoster('centre-1').first;
    expect(roster.map((c) => c.name), ['Aarav', 'Zoya']);
  });
}
