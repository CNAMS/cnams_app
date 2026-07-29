// Result view (R3): the reusable classification + z-score panel, and the
// standalone ResultScreen with its raise-referral CTA for SAM/MAM.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/features/measure/result_view.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        locale: const Locale('hi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

Measurement _measurement(String classification) {
  final t = DateTime.utc(2026, 6, 1);
  return Measurement(
    id: 'm1',
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
    weightG: 6800,
    lengthMm: 800,
    waz: -3.4,
    haz: -2.1,
    whz: -3.0,
    classification: classification,
  );
}

void main() {
  testWidgets('ResultView shows the word, z-scores and referral note for SAM', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const Scaffold(
          body: ResultView(
            classification: GrowthClass.sam,
            waz: -3.42,
            haz: -2.10,
            whz: -3.01,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('गंभीर कुपोषण (SAM)'), findsOneWidget);
    expect(find.text('-3.42'), findsOneWidget);
    expect(find.text('-2.10'), findsOneWidget);
    // SAM => referral advised note is shown.
    expect(
      find.text('इस बच्चे को ANM को दिखाने की सलाह दी जाती है'),
      findsOneWidget,
    );
  });

  testWidgets('ResultView hides the referral note for a normal result', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const Scaffold(
          body: ResultView(
            classification: GrowthClass.normal,
            waz: 0.1,
            haz: 0.2,
            whz: 0.0,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('सामान्य'), findsOneWidget);
    expect(
      find.text('इस बच्चे को ANM को दिखाने की सलाह दी जाती है'),
      findsNothing,
    );
  });

  testWidgets('ResultScreen offers a Refer CTA for a saved SAM measurement', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(ResultScreen(measurement: _measurement('sam'))),
    );
    await tester.pump();

    expect(find.text('गंभीर कुपोषण (SAM)'), findsOneWidget);
    expect(find.text('रेफ़रल भेजें'), findsOneWidget);
  });

  testWidgets('ResultScreen shows no Refer CTA for a normal measurement', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(ResultScreen(measurement: _measurement('normal'))),
    );
    await tester.pump();

    expect(find.text('सामान्य'), findsOneWidget);
    expect(find.text('रेफ़रल भेजें'), findsNothing);
  });
}
