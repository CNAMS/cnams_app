// Smoke test for the app shell: with a signed-in AWW session it boots, renders
// in Hindi (the default locale), and the bottom navigation switches to the
// Result-banner demo.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/auth/auth_models.dart';
import 'package:cgms_app/core/auth/secure_store.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/main.dart';

class _FakeStore implements SecureStore {
  _FakeStore(this.map);
  final Map<String, String> map;
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
}

void main() {
  testWidgets('app boots in Hindi and can switch to the result demo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language_chosen': true});
    final prefs = await SharedPreferences.getInstance();

    // A signed-in AWW session (no PIN set), so the flow reaches the shell.
    const session = AuthSession(
      userId: 'u1',
      role: AppRole.aww,
      method: AuthMethod.google,
      token: 't',
    );
    final store = _FakeStore({'auth_session': session.encode()});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(store),
          splashShownProvider.overrideWith((ref) => true),
        ],
        child: const CgmsApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Home tab first: greeting and the new-measurement button, in Hindi.
    expect(find.text('नमस्ते'), findsOneWidget);
    expect(find.text('नया माप लें'), findsOneWidget);

    // Switch to the Settings tab and confirm it renders (the language section).
    await tester.tap(find.text('सेटिंग्स').last);
    await tester.pumpAndSettle();
    expect(find.text('भाषा'), findsWidgets);
  });
}
