// Language screen: choosing a language sets the locale, persists the choice,
// and flips the language-chosen flag so the flow advances.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/core/settings/locale_controller.dart';
import 'package:cgms_app/features/onboarding/language_screen.dart';

void main() {
  testWidgets('choosing English sets locale, persists, and advances the flow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            final locale = ref.watch(localeControllerProvider);
            return MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const LanguageScreen(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Not chosen yet.
    expect(container.read(languageChosenProvider), isFalse);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(container.read(localeControllerProvider), const Locale('en'));
    expect(container.read(languageChosenProvider), isTrue);
    expect(prefs.getBool('language_chosen'), isTrue);
  });
}
