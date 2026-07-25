// Home / centre dashboard (FR-APP-17).
//
// The sync backlog is a real count from the outbox. The three stat tiles are
// still illustrative (marked with a sample chip) until per-day roster aggregates
// are wired — see docs/BUG_AUDIT.md #4.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/features/dashboard/dashboard_widgets.dart';
import 'package:cgms_app/features/roster/roster_screen.dart';
import 'package:cgms_app/shared/theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final pending = ref.watch(outboxCountsProvider).valueOrNull?.pending ?? 0;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.homeGreeting,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SampleChip(),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatTile(
                label: l10n.screenedToday,
                value: '12',
                color: AppTheme.styleFor(GrowthClass.normal).color,
                icon: Icons.check_circle,
              ),
              const SizedBox(width: 12),
              _StatTile(
                label: l10n.flaggedCount,
                value: '3',
                color: const Color(0xFFC62828),
                icon: Icons.flag,
              ),
              const SizedBox(width: 12),
              _StatTile(
                label: l10n.overdueCount,
                value: '5',
                color: const Color(0xFFF9A825),
                icon: Icons.schedule,
              ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RosterScreen()),
            ),
            icon: const Icon(Icons.add_a_photo),
            label: Text(l10n.newMeasurement),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(64),
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sync),
              title: Text(l10n.syncBacklog),
              trailing: Text(
                '$pending', // i18n-ignore: live count
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single dashboard count. Colour is backed by an icon so it isn't the only
/// signal.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
