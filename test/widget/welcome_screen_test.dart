// Welcome/landing screen (U2): shows the wordmark + tagline and fires the
// get-started callback that advances the first-run flow.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/features/onboarding/welcome_screen.dart';

void main() {
  testWidgets('shows the tagline and Get started advances the flow', (
    tester,
  ) async {
    var started = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WelcomeScreen(onGetStarted: () => started++),
      ),
    );
    // Let the intro animation settle.
    await tester.pumpAndSettle();

    expect(find.text('अंकुर'), findsOneWidget);
    expect(find.text('हर बच्चा, स्वस्थ विकास'), findsOneWidget);

    await tester.tap(find.text('शुरू करें'));
    expect(started, 1);
  });
}
