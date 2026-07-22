import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
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

/// Placeholder shell that proves localisation is wired end to end. The real
/// bottom-navigation host (Home / Roster / Centre / Settings) lands with those
/// features.
class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(child: Text(l10n.navHome)),
    );
  }
}
