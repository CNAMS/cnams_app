import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/core/settings/locale_controller.dart';
import 'package:cgms_app/core/auth/auth_controller.dart';
import 'package:cgms_app/features/auth/pin_unlock_screen.dart';
import 'package:cgms_app/features/auth/sign_in_screen.dart';
import 'package:cgms_app/features/onboarding/language_screen.dart';
import 'package:cgms_app/features/onboarding/splash_screen.dart';
import 'package:cgms_app/features/onboarding/welcome_screen.dart';
import 'package:cgms_app/features/shell/role_shell.dart';
import 'package:cgms_app/shared/theme/app_theme.dart';

/// Application entry point.
///
/// Hindi (`hi`) is the default locale on first launch; the worker can switch to
/// English from Settings and the choice persists. See
/// docs/PRODUCTION_ROADMAP.md — Phase P0 and the Localisation section.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Top-level error boundary: replace Flutter's raw red error box (which shows
  // exception text to the worker) with a calm, self-contained screen. The real
  // error still goes to the logs via the default FlutterError handler.
  ErrorWidget.builder = (details) => const _FriendlyErrorBox();

  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const CgmsApp(),
    ),
  );
}

/// A last-resort error screen shown when a widget throws during build. It cannot
/// assume a Localizations/Material ancestor (the failure may be above the app),
/// so it carries its own Directionality and shows the message bilingually.
class _FriendlyErrorBox extends StatelessWidget {
  const _FriendlyErrorBox();

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFFBF8F1),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 56, color: Color(0xFFC62828)),
                SizedBox(height: 16),
                Text(
                  'कुछ गड़बड़ हो गई', // i18n-ignore: pre-localization error boundary
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Something went wrong. Please reopen the app.', // i18n-ignore: error boundary
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFF4A4A4A)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
      home: const _AppFlow(),
    );
  }
}

/// First-run flow: splash → choose language → the app (PIN gate + shell).
/// Auth (EX2) will slot in between language and the gate.
class _AppFlow extends ConsumerWidget {
  const _AppFlow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splashShown = ref.watch(splashShownProvider);
    if (!splashShown) {
      return SplashScreen(
        onDone: () => ref.read(splashShownProvider.notifier).state = true,
      );
    }

    final languageChosen = ref.watch(languageChosenProvider);
    if (!languageChosen) {
      // First run: a premium welcome moment before the language choice.
      final welcomeShown = ref.watch(welcomeShownProvider);
      if (!welcomeShown) {
        return WelcomeScreen(
          onGetStarted: () =>
              ref.read(welcomeShownProvider.notifier).state = true,
        );
      }
      return const LanguageScreen();
    }

    // Signed out → sign in; signed in → the PIN gate + role shell.
    final session = ref.watch(authControllerProvider);
    return session.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SignInScreen(),
      data: (s) => s == null ? const SignInScreen() : const _Gate(),
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
      error: (_, __) => const RoleShell(),
      data: (isSet) =>
          (isSet && !unlocked) ? const PinUnlockScreen() : const RoleShell(),
    );
  }
}
