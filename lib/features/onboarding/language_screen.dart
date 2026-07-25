// The first decision: choose a language, before any account UI. The rest of the
// app then renders in the chosen language. Persisted; changeable later in
// Settings.
//
// See docs/ANKUR_EXPERIENCE_ROADMAP.md — EX1.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/core/settings/locale_controller.dart';
import 'package:cgms_app/features/onboarding/sprout_mark.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  Future<void> _choose(WidgetRef ref, Locale locale) async {
    await ref.read(localeControllerProvider.notifier).setLocale(locale);
    await ref.read(sharedPreferencesProvider).setBool('language_chosen', true);
    ref.read(languageChosenProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SproutMark(
                    size: 68,
                    stroke: theme.colorScheme.primary,
                    leafDark: const Color(0xFF2E7D32),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.chooseLanguage,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  _LangButton(
                    label: 'हिन्दी',
                    onTap: () => _choose(ref, const Locale('hi')),
                  ),
                  const SizedBox(height: 12),
                  _LangButton(
                    label: 'English',
                    onTap: () => _choose(ref, const Locale('en')),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.chooseLanguageHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  const _LangButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      // The language name is always shown in its own script.
      child: Text(label), // i18n-ignore: language endonym
    );
  }
}
