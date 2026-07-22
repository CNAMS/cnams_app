import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/shared/theme/app_theme.dart';

/// Application entry point.
///
/// Hindi (`hi`) is the primary and default locale; English (`en`) is the
/// fallback. See [docs/PRODUCTION_ROADMAP.md] phase P0.
void main() {
  runApp(const ProviderScope(child: CgmsApp()));
}

class CgmsApp extends StatelessWidget {
  const CgmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CGMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Hindi first, English fallback.
      locale: const Locale('hi'),
      supportedLocales: const [Locale('hi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(
        body: Center(child: Text('CGMS — scaffold')),
      ),
    );
  }
}
