// Schema migration policy for the local database.
//
// Version 1 just creates everything. When the schema changes, bump
// [schemaVersion] and add an `if (from <= N)` block in [strategy]; the
// migration round-trip test walks v1 -> latest so a missing step fails loudly
// rather than in the field. Phase P0.

import 'package:drift/drift.dart';

import 'package:cgms_app/core/db/app_database.dart';

class CgmsMigrations {
  const CgmsMigrations._();

  static const int schemaVersion = 1;

  static MigrationStrategy strategy(AppDatabase db) {
    return MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        // No upgrades yet — v1 is the first shipped schema.
      },
      beforeOpen: (details) async {
        // Enforce foreign keys on every connection (off by default in SQLite).
        await db.customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
