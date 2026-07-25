import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/core/settings/locale_controller.dart';
import 'package:cgms_app/features/auth/pin_unlock_screen.dart';
import 'package:cgms_app/features/home/home_screen.dart';
import 'package:cgms_app/features/measure/result_demo_screen.dart';
import 'package:cgms_app/features/roster/roster_screen.dart';
import 'package:cgms_app/features/settings/settings_screen.dart';
import 'package:cgms_app/shared/theme/app_theme.dart';

/// Application entry point.
///
/// Hindi (`hi`) is the default locale on first launch; the worker can switch to
/// English from Settings and the choice persists. See
/// docs/PRODUCTION_ROADMAP.md — Phase P0 and the Localisation section.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const CgmsApp(),
    ),
  );
}

class CgmsApp extends ConsumerWidget {
  const CgmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final role = ref.watch(currentRoleProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forRole(role, Brightness.light),
      darkTheme: AppTheme.forRole(role, Brightness.dark),
      themeMode: ThemeMode.system,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Gate(),
    );
  }
}

/// Shows the PIN unlock screen when a PIN is set and this session isn't unlocked
/// yet; otherwise the app shell. When no PIN is set, the app is open.
class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinSet = ref.watch(pinIsSetProvider);
    final unlocked = ref.watch(sessionUnlockedProvider);

    return pinSet.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const _AppShell(),
      data: (isSet) =>
          (isSet && !unlocked) ? const PinUnlockScreen() : const _AppShell(),
    );
  }
}

/// Bottom-navigation host. Today it carries Home and a Result-banner demo; the
/// full set (Roster / Centre / Settings) fills in as those features land.
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const pages = [
      HomeScreen(),
      RosterScreen(),
      ResultDemoScreen(),
      SettingsScreen(),
    ];
    final titles = [
      l10n.navHome,
      l10n.navRoster,
      l10n.navResultDemo,
      l10n.navSettings,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: l10n.navRoster,
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(Icons.assignment),
            label: l10n.navResultDemo,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
