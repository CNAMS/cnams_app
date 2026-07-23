// Settings language switch: tapping English re-renders the app in English and
// the choice persists.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/core/settings/locale_controller.dart';
import 'package:cgms_app/features/settings/settings_screen.dart';

Widget _wrap(SharedPreferences prefs) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: Consumer(
      builder: (context, ref, _) {
        final locale = ref.watch(localeControllerProvider);
        return MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // The real app's shell provides the Scaffold; supply one here.
          home: const Scaffold(body: SettingsScreen()),
        );
      },
    ),
  );
}

void main() {
  testWidgets('switches the app language to English and persists it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_wrap(prefs));
    await tester.pump();

    // Starts in Hindi.
    expect(find.text('भाषा'), findsOneWidget); // "Language" header in Hindi

    // Tap the English option.
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // Header is now in English, and the choice is saved.
    expect(find.text('Language'), findsOneWidget);
    expect(prefs.getString('app_locale'), 'en');
  });
}
