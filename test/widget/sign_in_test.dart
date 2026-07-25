// Sign-in flow: signed out shows sign-in; picking a role and continuing with
// Google signs in (mock) and reaches the app shell.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cgms_app/core/auth/secure_store.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/main.dart';

class _FakeStore implements SecureStore {
  final Map<String, String> map = {};
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
}

void main() {
  testWidgets('signed out shows sign-in; Google sign-in reaches the shell', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language_chosen': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(_FakeStore()),
          splashShownProvider.overrideWith((ref) => true),
        ],
        child: const CgmsApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Signed out → the sign-in screen (Hindi).
    expect(find.text('साइन इन करें'), findsWidgets);
    expect(find.text('Google से जारी रखें'), findsOneWidget);

    // AWW is preselected; continue with Google.
    await tester.tap(find.text('Google से जारी रखें'));
    await tester.pumpAndSettle();

    // Now on the AWW home.
    expect(find.text('नमस्ते'), findsOneWidget);
  });
}
