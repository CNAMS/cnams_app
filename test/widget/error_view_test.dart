// ErrorView (R6): a friendly, localised error state — never the raw exception —
// with an optional retry that runs the callback.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/shared/widgets/error_view.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('hi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('shows a friendly message, not the raw error', (tester) async {
    await tester.pumpWidget(
      _wrap(const ErrorView(error: 'SocketException: boom')),
    );
    await tester.pump();

    expect(find.text('कुछ गड़बड़ हो गई'), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);
  });

  testWidgets('retry button runs the callback', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      _wrap(ErrorView(error: 'x', onRetry: () => retried++)),
    );
    await tester.pump();

    expect(find.text('फिर कोशिश करें'), findsOneWidget);
    await tester.tap(find.text('फिर कोशिश करें'));
    expect(retried, 1);
  });

  testWidgets('no retry button when no callback is given', (tester) async {
    await tester.pumpWidget(_wrap(const ErrorView()));
    await tester.pump();
    expect(find.text('फिर कोशिश करें'), findsNothing);
  });
}
