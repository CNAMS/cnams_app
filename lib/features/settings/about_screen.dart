// About screen (R4): the Ankur mark, product name, version, a one-line tagline,
// and a proper open-source licenses page (Flutter's showLicensePage).
//
// See docs/REFINEMENT_ROADMAP.md — R4.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/app_info.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/features/onboarding/sprout_mark.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAbout)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          children: [
            Center(
              child: SproutMark(
                size: 96,
                stroke: theme.colorScheme.onSurfaceVariant,
                leafLight: theme.colorScheme.primary.withValues(alpha: 0.55),
                leafDark: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.appTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.settingsAboutSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.aboutTagline,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.aboutVersion(appVersion)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.aboutLicenses),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationIcon: const Padding(
                  padding: EdgeInsets.all(8),
                  child: SproutMark(size: 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
