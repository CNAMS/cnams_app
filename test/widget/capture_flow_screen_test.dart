// Capture flow: weight and length share one page, both fill from one scale
// cycle, implausible typed values are blocked, and Back keeps what was entered.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cgms_app/core/auth/secure_store.dart';
import 'package:cgms_app/core/ble/device_client.dart';
import 'package:cgms_app/core/ble/mock_device_client.dart';
import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/core/zscore/reference_tables.dart';
import 'package:cgms_app/features/measure/capture_flow_screen.dart';

class _FakeStore implements SecureStore {
  final Map<String, String> map = {};
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
}

Child _child() {
  final t = DateTime.utc(2026, 1, 1);
  return Child(
    id: 'child-1',
    centreId: 'c1',
    name: 'Aarav',
    sex: 'M',
    dob: DateTime.now().subtract(const Duration(days: 500)),
    dobPrecision: 'exact',
    consentStatus: 'given',
    createdAt: t,
    updatedAt: t,
    deleted: false,
  );
}

const _tick = Duration(milliseconds: 50);

Future<void> _pumpFlow(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStoreProvider.overrideWithValue(_FakeStore()),
        referenceTablesProvider.overrideWith(
          (ref) => ReferenceTables(const []),
        ),
        deviceClientProvider.overrideWith(
          (ref) => MockDeviceClient(
            targets: const {
              DeviceChannel.weight: 9450,
              DeviceChannel.length: 781,
            },
            stabilizeAfter: 1,
            tickInterval: _tick,
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CaptureFlowScreen(child: _child()),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // Let the route animate in, the mock connect, and a few readings arrive.
  for (var i = 0; i < 12; i++) {
    await tester.pump(_tick);
  }
}

/// Tear the screen down and let the mock's last tick run out.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(_tick * 3);
}

Finder _field(String label) => find.widgetWithText(TextField, label);

void main() {
  testWidgets('weight and length are captured on the same page', (
    tester,
  ) async {
    await _pumpFlow(tester);

    expect(find.text('Step 1 of 3 · Weight & length'), findsOneWidget);
    expect(find.text('Scale connected'), findsOneWidget);
    expect(_field('Weight'), findsOneWidget);
    expect(_field('Length'), findsOneWidget);

    // One scale cycle filled both boxes.
    expect(find.widgetWithText(TextField, '9.45'), findsOneWidget);
    expect(find.widgetWithText(TextField, '78.1'), findsOneWidget);

    await tester.tap(find.text('Next'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(_tick);
    }
    expect(find.text('Step 2 of 3 · MUAC'), findsOneWidget);

    await _finish(tester);
  });

  testWidgets('an implausible value is flagged and blocks Next', (
    tester,
  ) async {
    await _pumpFlow(tester);

    await tester.enterText(_field('Weight'), '105');
    await tester.pump();

    expect(find.textContaining('expected 0.5–40 kg'), findsOneWidget);
    final next = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Next'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(next.onPressed, isNull);

    await _finish(tester);
  });

  testWidgets('Back from MUAC returns to weight & length with values kept', (
    tester,
  ) async {
    await _pumpFlow(tester);
    await tester.tap(find.text('Next'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(_tick);
    }

    await tester.tap(find.text('Back'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(_tick);
    }

    expect(find.text('Step 1 of 3 · Weight & length'), findsOneWidget);
    expect(find.widgetWithText(TextField, '9.45'), findsOneWidget);

    await _finish(tester);
  });
}
