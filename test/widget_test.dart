// Smoke test for the app shell: it boots, renders in Hindi (the default
// locale), and the bottom navigation switches to the Result-banner demo.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/main.dart';

void main() {
  testWidgets('app boots in Hindi and can switch to the result demo',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CgmsApp()));
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
