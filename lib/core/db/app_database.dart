// The drift database: opens the on-device SQLite file and wires up the DAOs.
//
// Encryption note: the storage file will be SQLCipher-encrypted with a key
// derived from the worker's PIN. That key handling lands in Phase P4 alongside
// the PIN gate; [openConnection] already takes an optional passphrase so the
// call site changes but the schema doesn't. Until then it opens unencrypted so
// the rest of the app can be built and tested. See docs/PRODUCTION_ROADMAP.md.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:cgms_app/core/db/daos/children_dao.dart';
import 'package:cgms_app/core/db/daos/measurements_dao.dart';
import 'package:cgms_app/core/db/daos/outbox_dao.dart';
import 'package:cgms_app/core/db/daos/referrals_dao.dart';
import 'package:cgms_app/core/db/migrations.dart';
import 'package:cgms_app/core/db/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Centres, Children, Measurements, Referrals, Outbox],
  daos: [ChildrenDao, MeasurementsDao, ReferralsDao, OutboxDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  /// Bump this on every schema change; each step is exercised in the migration
  /// round-trip test.
  @override
  int get schemaVersion => CgmsMigrations.schemaVersion;

  @override
  MigrationStrategy get migration => CgmsMigrations.strategy(this);
}

/// Opens the database file under the app's documents directory.
///
/// When a [passphrase] is supplied the connection is keyed with SQLCipher via
/// `PRAGMA key` before any other statement. The passphrase itself is derived
/// from the worker's PIN and passed in after unlock.
///
/// Remaining P4 wiring (why this is a structural seam, not a finished feature):
///   1. On Android, `open.overrideFor(...)` must point at the SQLCipher build
///      from sqlcipher_flutter_libs so the encrypted `PRAGMA key` is honoured.
///   2. The database must be opened AFTER PIN unlock, so the app composition
///      order changes (appDatabaseProvider becomes keyed on the derived key).
///   3. A migration path for any existing plaintext DB.
QueryExecutor openConnection({String? passphrase}) {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'cgms.sqlite'));
    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        if (passphrase != null) {
          // Must run before any other statement on the connection.
          db.execute("PRAGMA key = '${passphrase.replaceAll("'", "''")}';");
        }
      },
    );
  });
}
