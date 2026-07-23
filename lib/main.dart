import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/features/home/home_screen.dart';
import 'package:cgms_app/features/measure/result_demo_screen.dart';
import 'package:cgms_app/features/roster/roster_screen.dart';
import 'package:cgms_app/shared/theme/app_theme.dart';

/// Application entry point.
///
/// Hindi (`hi`) is the primary and default locale; English (`en`) is the
/// fallback. See docs/PRODUCTION_ROADMAP.md — Phase P0.
void main() {
  runApp(const ProviderScope(child: CgmsApp()));
}

class CgmsApp extends StatelessWidget {
  const CgmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Hindi first, English fallback.
      locale: const Locale('hi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _AppShell(),
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
    const pages = [HomeScreen(), RosterScreen(), ResultDemoScreen()];
    final titles = [l10n.navHome, l10n.navRoster, l10n.navResultDemo];

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
        ],
      ),
    );
  }
}
