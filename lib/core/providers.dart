// Composition root: the Riverpod providers that wire the database and
// repositories together. Screens read these, never construct their own.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P1.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/data/centre_repository.dart';
import 'package:cgms_app/core/data/child_repository.dart';
import 'package:cgms_app/core/db/app_database.dart';

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
