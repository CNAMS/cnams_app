// Smoke test for the app shell: it boots, renders in Hindi (the default
// locale), and the bottom navigation switches to the Result-banner demo.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/main.dart';

void main() {
  testWidgets('app boots in Hindi and can switch to the result demo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // No secure storage in a widget test: no PIN, so the gate opens.
          pinIsSetProvider.overrideWith((ref) => false),
        ],
        child: const CgmsApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Home tab first: greeting and the new-measurement button, in Hindi.
    expect(find.text('नमस्ते'), findsOneWidget);
    expect(find.text('नया माप लें'), findsOneWidget);

    // Switch to the Result-demo tab and confirm the top of the gallery renders
    // (the first banner is "normal"; later bands are offscreen in this small
    // test viewport and not built yet).
    await tester.tap(find.text('परिणाम नमूना').last);
    await tester.pumpAndSettle();
    expect(find.text('सामान्य'), findsOneWidget);
  });
}
