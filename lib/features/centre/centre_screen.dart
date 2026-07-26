// Centre view (FR-APP-14, R1): the AWW's own rollup — screened this month,
// flagged (SAM/MAM) and overdue — plus the lists behind those counts. All
// computed from the local database via the roster, so it works offline.
//
// See docs/REFINEMENT_ROADMAP.md — R1.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/data/child_repository.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/features/dashboard/dashboard_widgets.dart';
import 'package:cgms_app/features/history/child_history_screen.dart';
import 'package:cgms_app/shared/theme/app_theme.dart';

class CentreScreen extends ConsumerWidget {
  const CentreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final roster = ref.watch(rosterProvider);
    final stats = ref.watch(centreStatsProvider);

    return SafeArea(
      child: roster.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')), // i18n-ignore: diagnostic
        data: (entries) {
          final flagged = entries.where((e) => e.isFlagged).toList();
          final overdue = entries.where((e) => e.isOverdue).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  DashStatTile(
                    value: '${stats.screenedThisMonth}',
                    label: l10n.centreScreenedThisMonth,
                    color: AppTheme.styleFor(GrowthClass.normal).color,
                    icon: Icons.check_circle,
                  ),
                  const SizedBox(width: 8),
                  DashStatTile(
                    value: '${stats.flagged}',
                    label: l10n.flaggedCount,
                    color: const Color(0xFFC62828),
                    icon: Icons.flag,
                  ),
                  const SizedBox(width: 8),
                  DashStatTile(
                    value: '${stats.overdue}',
                    label: l10n.overdueCount,
                    color: const Color(0xFFE68A00),
                    icon: Icons.schedule,
                  ),
                ],
              ),
              DashSection(title: l10n.centreFlaggedChildren),
              if (flagged.isEmpty)
                _EmptyLine(text: l10n.centreNoneFlagged)
              else
                for (final e in flagged) _ChildRow(entry: e),
              DashSection(title: l10n.centreOverdueChildren),
              if (overdue.isEmpty)
                _EmptyLine(text: l10n.centreNoneOverdue)
              else
                for (final e in overdue) _ChildRow(entry: e),
            ],
          );
        },
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({required this.entry});

  final RosterEntry entry;

  GrowthClass _classOf(String? name) => GrowthClass.values.firstWhere(
        (c) => c.name == name,
        orElse: () => GrowthClass.indeterminate,
      );

  @override
  Widget build(BuildContext context) {
    final child = entry.child;
    final style = AppTheme.styleFor(_classOf(entry.lastClassification));
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: style.color.withValues(alpha: 0.15),
        child: Text(
          child.name.isEmpty ? '?' : child.name.characters.first,
          style: TextStyle(color: style.color, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(child.name),
      trailing: Icon(Icons.chevron_right, color: style.color),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChildHistoryScreen(child: child),
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.check, size: 18, color: Theme.of(context).disabledColor),
          const SizedBox(width: 8),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
