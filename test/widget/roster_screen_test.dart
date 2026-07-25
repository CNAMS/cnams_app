// Roster screen rendering + filtering.
//
// The roster provider is overridden with a plain stream of view models, so the
// test exercises the real widget (list, search, overdue badge, empty state)
// without a live database. Pumping the full app against an in-memory drift
// STREAM keeps the test event loop busy and never settles, which is why we
// isolate the screen here instead.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/data/child_repository.dart';
import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/features/roster/roster_screen.dart';

Child _child(String id, String name, String guardian) {
  final t = DateTime.utc(2026, 1, 1);
  return Child(
    id: id,
    centreId: 'c1',
    name: name,
    sex: 'M',
    dob: DateTime.utc(2024, 6, 1),
    dobPrecision: 'exact',
    guardianName: guardian,
    consentStatus: 'given',
    createdAt: t,
    updatedAt: t,
    deleted: false,
  );
}

Future<void> _pumpRoster(
  WidgetTester tester,
  List<RosterEntry> entries,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rosterProvider.overrideWith((ref) => Stream.value(entries)),
      ],
      child: const MaterialApp(
        locale: Locale('hi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RosterScreen(),
      ),
    ),
  );
  await tester.pump(); // deliver the stream value
}

void main() {
  testWidgets('lists children and shows an overdue badge', (tester) async {
    await _pumpRoster(tester, [
      RosterEntry(
        child: _child('1', 'Aarav', 'Sita'),
        lastMeasuredAt: null,
        isOverdue: true,
      ),
      RosterEntry(
        child: _child('2', 'Diya', 'Ram'),
        lastMeasuredAt: DateTime.utc(2026, 6, 1),
        isOverdue: false,
      ),
    ]);

    expect(find.text('Aarav'), findsOneWidget);
    expect(find.text('Diya'), findsOneWidget);
    // Only the never-measured child is overdue.
    expect(find.text('बकाया'), findsOneWidget);
  });

  testWidgets('search filters on name and guardian', (tester) async {
    await _pumpRoster(tester, [
      RosterEntry(
        child: _child('1', 'Aarav', 'Sita'),
        lastMeasuredAt: null,
        isOverdue: true,
      ),
      RosterEntry(
        child: _child('2', 'Diya', 'Ram'),
        lastMeasuredAt: null,
        isOverdue: true,
      ),
    ]);

    await tester.enterText(find.byType(TextField).first, 'Ram');
    await tester.pump();

    expect(find.text('Diya'), findsOneWidget);
    expect(find.text('Aarav'), findsNothing);
  });

  testWidgets('shows an empty state when there are no children',
      (tester) async {
    await _pumpRoster(tester, []);
    expect(find.text('अभी तक कोई बच्चा नहीं जोड़ा गया'), findsOneWidget);
  });
}
