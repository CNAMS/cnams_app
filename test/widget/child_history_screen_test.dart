// Child history screen: renders the latest banner and the previous visits from
// a stubbed measurements stream (no live database, so no settle hang).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/core/zscore/reference_tables.dart';
import 'package:cgms_app/features/history/child_history_screen.dart';

Child _child() {
  final t = DateTime.utc(2026, 1, 1);
  return Child(
    id: 'child-1',
    centreId: 'c1',
    name: 'Aarav',
    sex: 'M',
    dob: DateTime.utc(2024, 6, 1),
    dobPrecision: 'exact',
    consentStatus: 'given',
    createdAt: t,
    updatedAt: t,
    deleted: false,
  );
}

Measurement _measurement(String id, String classification, int weightG) {
  final t = DateTime.utc(2026, 6, 1);
  return Measurement(
    id: id,
    childId: 'child-1',
    measuredAt: t,
    ageDays: 500,
    oedema: false,
    source: 'manual',
    engineVersion: 'test',
    appVersion: 'test',
    workerId: 'w1',
    createdAt: t,
    updatedAt: t,
    weightG: weightG,
    lengthMm: 800,
    classification: classification,
  );
}

void main() {
  testWidgets('shows the latest classification and lists visits', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          measurementsProvider('child-1').overrideWith(
            (ref) => Stream.value([
              _measurement('m2', 'sam', 6800),
              _measurement('m1', 'mam', 7200),
            ]),
          ),
          referenceTablesProvider.overrideWith(
            (ref) => ReferenceTables(const []),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('hi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChildHistoryScreen(child: _child()),
        ),
      ),
    );
    await tester.pump();

    // Latest (newest-first) is SAM, shown in the banner.
    expect(find.text('गंभीर कुपोषण (SAM)'), findsWidgets);
    // The older MAM visit is listed too.
    expect(find.text('मध्यम कुपोषण (MAM)'), findsOneWidget);
  });
}
