// Settings.
//
// P1 shipped the language switch. P4 adds the Data & security section: the sync
// backlog and dead-letter counts, CSV export (shared as a file), and PIN setup.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:cgms_app/core/auth/auth_controller.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/core/settings/locale_controller.dart';
import 'package:cgms_app/features/auth/role_display.dart';
import 'package:cgms_app/features/export/csv_export.dart';
import 'package:cgms_app/features/settings/about_screen.dart';
import 'package:cgms_app/shared/theme/design_tokens.dart';
import 'package:cgms_app/shared/widgets/premium.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final centreId = await ref.read(currentCentreProvider.future);
    final rows = await ref
        .read(measurementRepositoryProvider)
        .measurementsWithChildren(centreId);

    if (rows.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportNoData)));
      return;
    }

    final csv = buildMeasurementCsv([
      for (final (child, measurement) in rows)
        ExportRow(child: child, measurement: measurement),
    ]);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'cgms_export.csv'));
    await file.writeAsString(csv);
    try {
      await Share.shareXFiles([XFile(file.path)], subject: l10n.exportSubject);
    } finally {
      // Don't leave the export sitting in the temp dir.
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {
          /* best-effort cleanup */
        }
      }
    }
  }

  Future<void> _setPin(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _PinDialog(),
    );
    if (pin == null || pin.isEmpty) return;
    await ref.read(pinAuthProvider).setPin(pin);
    ref.invalidate(pinIsSetProvider);
    messenger.showSnackBar(SnackBar(content: Text(l10n.pinSaved)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeControllerProvider);
    final controller = ref.read(localeControllerProvider.notifier);
    final counts = ref.watch(outboxCountsProvider);
    final pinSet = ref.watch(pinIsSetProvider).valueOrNull ?? false;
    final role = ref.watch(currentRoleProvider);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GradientHeader(
          role: role,
          title: l10n.navSettings,
          subtitle: roleLabel(l10n, role),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.22),
            child: Icon(roleIcon(role), color: Colors.white),
          ),
          trailing: TextButton.icon(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout, color: Colors.white, size: 18),
            label:
                Text(l10n.signOut, style: const TextStyle(color: Colors.white)),
          ),
        ),
        Reveal(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(title: l10n.settingsLanguage),
                PremiumCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: [
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
                    ],
                  ),
                ),
                SectionTitle(title: l10n.settingsDataSecurity),
                PremiumCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.sync),
                        title: Text(l10n.syncBacklog),
                        trailing: Text(
                          '${counts.valueOrNull?.pending ?? 0}', // i18n-ignore: count
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: Text(l10n.syncDeadLetter),
                        trailing: Text(
                          '${counts.valueOrNull?.deadLetter ?? 0}', // i18n-ignore: count
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.table_view),
                        title: Text(l10n.exportCsv),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _exportCsv(context, ref),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.pin),
                        title: Text(pinSet ? l10n.pinChange : l10n.pinSet),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _setPin(context, ref),
                      ),
                    ],
                  ),
                ),
                SectionTitle(title: l10n.settingsAbout),
                PremiumCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(l10n.settingsAbout),
                    subtitle: Text(l10n.settingsAboutSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const AboutScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple numeric PIN entry dialog; returns the entered PIN (4-6 digits).
class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.pinCreate),
      content: TextField(
        controller: _pin,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          counterText: '',
          helperText: l10n.pinHint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _pin.text.trim().length >= 4
              ? () => Navigator.of(context).pop(_pin.text.trim())
              : null,
          child: Text(l10n.save),
        ),
      ],
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
