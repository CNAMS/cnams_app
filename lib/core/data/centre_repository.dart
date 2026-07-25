// Centre repository.
//
// P1 works against a single local centre so registration has a valid centre_id
// to reference. Choosing/managing centres (ICDS code, sector, block) is a later
// phase; for now we ensure one default row exists and hand back its id.

import 'package:drift/drift.dart';

import 'package:cgms_app/core/db/app_database.dart';

class CentreRepository {
  CentreRepository(this._db);

  final AppDatabase _db;

  /// Fixed id for the single local centre. Stable so re-seeding is a no-op.
  static const String defaultCentreId = 'local-default-centre';

  /// Ensure the default centre exists and return its id.
  Future<String> ensureDefault() async {
    await _db.into(_db.centres).insert(
          CentresCompanion.insert(
            id: defaultCentreId,
            name: 'स्थानीय केंद्र',
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return defaultCentreId;
  }
}
