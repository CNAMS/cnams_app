// Schema sanity checks for a fresh database.
//
// A full drift schema-migration harness (verifying v1 -> latest) gets wired in
// when the first real migration lands; for now this proves a fresh db creates
// every table and enforces the constraints we rely on. Phase P0.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/db/migrations.dart';

void main() {
  test('fresh database reports the expected schema version', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, CgmsMigrations.schemaVersion);
    await db.close();
  });

  test('all five tables are created and queryable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    // A count on each table forces it to exist; a missing table would throw.
    expect(await db.select(db.centres).get(), isEmpty);
    expect(await db.select(db.children).get(), isEmpty);
    expect(await db.select(db.measurements).get(), isEmpty);
    expect(await db.select(db.referrals).get(), isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
    await db.close();
  });

  test('foreign keys are enforced (a child needs a real centre)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    // beforeOpen runs PRAGMA foreign_keys = ON, so this insert must fail.
    final now = DateTime.utc(2026, 1, 1);
    await expectLater(
      db.into(db.children).insert(
            ChildrenCompanion.insert(
              id: 'orphan',
              centreId: 'does-not-exist',
              name: 'X',
              sex: 'M',
              dob: DateTime.utc(2024, 1, 1),
              dobPrecision: 'exact',
              consentStatus: 'none',
              createdAt: now,
              updatedAt: now,
            ),
          ),
      throwsA(isA<Exception>()),
    );
    await db.close();
  });
}
