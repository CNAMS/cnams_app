// Centre view: renders flagged and overdue children from a stubbed roster and
// the derived counts.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/data/child_repository.dart';
import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/features/centre/centre_screen.dart';

Child _child(String id, String name) {
  final t = DateTime.utc(2026, 1, 1);
  return Child(
    id: id,
    centreId: 'c1',
    name: name,
    sex: 'M',
    dob: DateTime.utc(2024, 6, 1),
    dobPrecision: 'exact',
    consentStatus: 'given',
    createdAt: t,
    updatedAt: t,
    deleted: false,
  );
}

void main() {
  testWidgets('shows flagged and overdue children with counts', (tester) async {
    final entries = [
      RosterEntry(
        child: _child('1', 'Aarav'),
        lastMeasuredAt: DateTime(2020),
        isOverdue: true,
        lastClassification: 'sam',
      ),
      RosterEntry(
        child: _child('2', 'Diya'),
        lastMeasuredAt: DateTime.now(),
        isOverdue: false,
        lastClassification: 'normal',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rosterProvider.overrideWith((ref) => Stream.value(entries)),
        ],
        child: const MaterialApp(
          locale: Locale('hi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CentreScreen()),
        ),
      ),
    );
    await tester.pump();

    // Aarav is SAM (flagged) and overdue; Diya is neither.
    expect(find.text('Aarav'), findsWidgets);
    expect(find.text('चिह्नित बच्चे'), findsOneWidget); // flagged section
    expect(find.text('बकाया बच्चे'), findsOneWidget); // overdue section
  });
}
