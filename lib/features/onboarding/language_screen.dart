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
import 'package:cgms_app/shared/theme/design_tokens.dart';

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
                  const SizedBox(height: 28),
                  _LangCard(
                    label: 'हिन्दी',
                    sublabel: 'Hindi',
                    onTap: () => _choose(ref, const Locale('hi')),
                  ),
                  const SizedBox(height: 12),
                  _LangCard(
                    label: 'English',
                    sublabel: 'English',
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

/// A selectable language card — the endonym large in its own script, the Latin
/// name beneath, a globe chip, and a chevron. Softer and more premium than a
/// plain button.
class _LangCard extends StatelessWidget {
  const _LangCard({
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppRadius.allLg,
      child: InkWell(
        borderRadius: AppRadius.allLg,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.allLg,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.allMd,
                ),
                child: Icon(Icons.language, color: primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The language name is always shown in its own script.
                    Text(
                      label, // i18n-ignore: language endonym
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    // The Latin name, only when it adds something (e.g. under
                    // "हिन्दी"); skipped when it would just repeat the endonym.
                    if (sublabel != label)
                      Text(
                        sublabel, // i18n-ignore: language name (Latin)
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
