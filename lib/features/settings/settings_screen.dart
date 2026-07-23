// Settings.
//
// P1 ships the language switch (Hindi ⇄ English), which takes effect
// immediately and persists across restarts. Sync status, device management and
// the dead-letter view are added in P4.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/settings/locale_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeControllerProvider);
    final controller = ref.read(localeControllerProvider.notifier);

    return SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.language),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsLanguage,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      l10n.settingsLanguageSubtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _LanguageOption(
            label: l10n.languageHindi,
            selected: locale.languageCode == 'hi',
            onTap: () => controller.setLocale(const Locale('hi')),
          ),
          _LanguageOption(
            label: l10n.languageEnglish,
            selected: locale.languageCode == 'en',
            onTap: () => controller.setLocale(const Locale('en')),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            subtitle: Text(l10n.settingsAboutSubtitle),
          ),
        ],
      ),
    );
  }
}

/// A selectable language row. The tick (plus the highlighted text) means the
/// choice is never signalled by colour alone.
class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ListTile(
      onTap: onTap,
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? color : null,
        ),
      ),
      trailing: selected ? Icon(Icons.check, color: color) : null,
    );
  }
}
