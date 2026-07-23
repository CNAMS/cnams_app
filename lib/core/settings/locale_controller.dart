// Runtime app-language control.
//
// The worker can switch between Hindi and English from Settings; the choice is
// persisted so it survives a restart. Hindi is the default on first launch, in
// keeping with the app's Hindi-first stance.
//
// See docs/PRODUCTION_ROADMAP.md — Localisation & accessibility.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/providers.dart';

/// Locales the app can switch between. Hindi first.
const List<Locale> appLocales = [Locale('hi'), Locale('en')];

const String _localeKey = 'app_locale';

/// Holds the active [Locale], loaded from and saved to SharedPreferences.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final code = ref.watch(sharedPreferencesProvider).getString(_localeKey);
    return _localeFor(code);
  }

  /// Change the app language and persist it.
  Future<void> setLocale(Locale locale) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_localeKey, locale.languageCode);
    state = locale;
  }

  static Locale _localeFor(String? code) =>
      code == 'en' ? const Locale('en') : const Locale('hi');
}

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);
