// Settings.
//
// P1 shipped the language switch. P4 adds the Data & security section: the sync
// backlog and dead-letter counts, CSV export (shared as a file), and PIN setup.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:cgms_app/core/auth/auth_controller.dart';
import 'package:cgms_app/core/ble/scale_pairing_controller.dart';
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
                SectionTitle(title: l10n.settingsBleScale),
                PremiumCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final pairedScale = ref.watch(scalePairingProvider);
                      final isPaired = pairedScale.isPaired;

                      return ListTile(
                        leading: Icon(
                          isPaired
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_searching,
                          color: isPaired
                              ? const Color(0xFF2E7D32)
                              : Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          isPaired
                              ? l10n.bleScalePaired(
                                  pairedScale.name ?? pairedScale.id!)
                              : l10n.bleScaleNotPaired,
                          style: TextStyle(
                            fontWeight:
                                isPaired ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          isPaired
                              ? (pairedScale.id ?? '')
                              : l10n.settingsBleScaleSubtitle,
                        ),
                        trailing: isPaired
                            ? TextButton.icon(
                                icon: const Icon(Icons.link_off, size: 16),
                                label: Text(l10n.bleScaleUnpairAction),
                                onPressed: () => ref
                                    .read(scalePairingProvider.notifier)
                                    .unpair(),
                              )
                            : FilledButton.tonalIcon(
                                icon: const Icon(Icons.search, size: 16),
                                label: Text(l10n.bleScalePairAction),
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (_) => const _ScalePairingDialog(),
                                ),
                              ),
                      );
                    },
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

/// Dialog that scans for nearby CGMS scales and allows the worker to pair one.
class _ScalePairingDialog extends ConsumerStatefulWidget {
  const _ScalePairingDialog();

  @override
  ConsumerState<_ScalePairingDialog> createState() =>
      _ScalePairingDialogState();
}

class _ScalePairingDialogState extends ConsumerState<_ScalePairingDialog> {
  List<ScanResult> _devices = [];
  bool _scanning = false;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _scanningSub;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    _devices.clear();
    setState(() => _scanning = true);

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        // Filter devices matching CGMS prefix or service UUID
        final cgms = results.where((r) {
          final name = r.device.platformName;
          final advName = r.advertisementData.advName;
          return name.startsWith('CGMS') ||
              advName.startsWith('CGMS') ||
              r.advertisementData.serviceUuids
                  .contains(Guid('4fafc201-1fb5-459e-8fcc-c5c9c331914b'));
        }).toList();

        // Sort by signal strength (strongest first)
        cgms.sort((a, b) => b.rssi.compareTo(a.rssi));

        setState(() {
          _devices = cgms;
        });
      }
    });

    _scanningSub = FlutterBluePlus.isScanning.listen((isScanning) {
      if (mounted) setState(() => _scanning = isScanning);
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid('4fafc201-1fb5-459e-8fcc-c5c9c331914b')],
        timeout: const Duration(seconds: 10),
      );
    } catch (_) {
      // Fallback: scan without service filter if device advertises without UUID in packet
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _scanningSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.bluetooth_searching),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.settingsBleScale)),
          if (_scanning)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _devices.isEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),
                  if (_scanning) ...[
                    Text(l10n.bleScaleScanning, textAlign: TextAlign.center),
                  ] else ...[
                    const Icon(Icons.bluetooth_disabled,
                        size: 40, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(l10n.bleScaleNoDevicesFound,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.retry),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: _devices.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = _devices[i];
                  final name = r.device.platformName.isNotEmpty
                      ? r.device.platformName
                      : (r.advertisementData.advName.isNotEmpty
                          ? r.advertisementData.advName
                          : 'CGMS Scale'); // i18n-ignore
                  final id = r.device.remoteId.str;
                  final rssi = r.rssi;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: const Icon(Icons.scale),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(id),
                    trailing: Chip(
                      label: Text('$rssi dBm'), // i18n-ignore: metric
                      visualDensity: VisualDensity.compact,
                    ),
                    onTap: () async {
                      await ref
                          .read(scalePairingProvider.notifier)
                          .pair(id, name);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(l10n.bleScalePairSuccess(name))),
                        );
                      }
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
