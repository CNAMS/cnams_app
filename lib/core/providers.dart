// Composition root: the Riverpod providers that wire the database and
// repositories together. Screens read these, never construct their own.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P1.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cgms_app/core/ble/device_client.dart';
import 'package:cgms_app/core/ble/mock_device_client.dart';
import 'package:cgms_app/core/data/centre_repository.dart';
import 'package:cgms_app/core/data/child_repository.dart';
import 'package:cgms_app/core/data/measurement_repository.dart';
import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/reference/reference_loader.dart';
import 'package:cgms_app/core/zscore/reference_tables.dart';
import 'package:cgms_app/core/zscore/who_lms_engine.dart';
import 'package:cgms_app/core/zscore/zscore_engine.dart';

/// The app's SharedPreferences, resolved once at startup and injected here.
/// Overridden in main() (and in tests) so the rest of the app can read it
/// synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override sharedPreferencesProvider'),
);

/// The single database instance for the app's lifetime.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final centreRepositoryProvider = Provider<CentreRepository>(
  (ref) => CentreRepository(ref.watch(appDatabaseProvider)),
);

final childRepositoryProvider = Provider<ChildRepository>(
  (ref) => ChildRepository(ref.watch(appDatabaseProvider)),
);

final measurementRepositoryProvider = Provider<MeasurementRepository>(
  (ref) => MeasurementRepository(ref.watch(appDatabaseProvider)),
);

/// The measuring device. P2 always returns the mock; P3 swaps in the real
/// flutter_blue_plus client behind the same interface.
final deviceClientProvider = Provider<DeviceClient>(
  (ref) => MockDeviceClient(),
);

/// The centre the app is currently operating in. P1 resolves this to the single
/// local centre, seeding it on first read.
final currentCentreProvider = FutureProvider<String>(
  (ref) => ref.watch(centreRepositoryProvider).ensureDefault(),
);

/// Live roster for the current centre.
final rosterProvider = StreamProvider<List<RosterEntry>>((ref) async* {
  final centreId = await ref.watch(currentCentreProvider.future);
  yield* ref.watch(childRepositoryProvider).watchRoster(centreId);
});

/// The bundled WHO reference tables, loaded once from assets.
final referenceTablesProvider = FutureProvider<ReferenceTables>(
  (ref) => loadReferenceTables(),
);

/// The z-score engine, built over the loaded reference tables.
final zscoreEngineProvider = FutureProvider<ZScoreEngine>((ref) async {
  final tables = await ref.watch(referenceTablesProvider.future);
  return WhoLmsEngine(tables);
});
