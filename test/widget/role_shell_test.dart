// Role shell: each role opens its own dashboard as the first tab, and can't see
// another role's surface (the destinations aren't built for it).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/features/shell/role_shell.dart';

Future<void> _pump(WidgetTester tester, AppRole role) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentRoleProvider.overrideWith((ref) => role)],
      child: const MaterialApp(
        locale: Locale('hi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RoleShell(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('doctor opens the referred-cases dashboard', (tester) async {
    await _pump(tester, AppRole.doctor);
    expect(
        find.text('रेफ़र किए गए मामले'), findsOneWidget); // dashReferredCases
    // No AWW greeting for a doctor.
    expect(find.text('नमस्ते'), findsNothing);
  });

  testWidgets('supervisor opens the sector overview', (tester) async {
    await _pump(tester, AppRole.supervisor);
    expect(find.text('क्षेत्र अवलोकन'), findsOneWidget); // dashSectorOverview
  });

  testWidgets('admin opens the console with pending approvals', (tester) async {
    await _pump(tester, AppRole.admin);
    expect(
        find.text('लंबित स्वीकृतियाँ'), findsOneWidget); // dashPendingApprovals
  });
}
