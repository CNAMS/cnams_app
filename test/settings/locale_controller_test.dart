// LocaleController tests: default, persistence, and load-from-storage.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/core/settings/locale_controller.dart';

Future<ProviderContainer> containerWith(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('defaults to Hindi when nothing is stored', () async {
    final container = await containerWith({});
    expect(
      container.read(localeControllerProvider),
      const Locale('hi'),
    );
  });

  test('loads the stored language on start', () async {
    final container = await containerWith({'app_locale': 'en'});
    expect(
      container.read(localeControllerProvider),
      const Locale('en'),
    );
  });

  test('setLocale updates state and persists the choice', () async {
    final container = await containerWith({});
    final controller = container.read(localeControllerProvider.notifier);

    await controller.setLocale(const Locale('en'));
    expect(container.read(localeControllerProvider), const Locale('en'));

    final prefs = container.read(sharedPreferencesProvider);
    expect(prefs.getString('app_locale'), 'en');
  });
}
