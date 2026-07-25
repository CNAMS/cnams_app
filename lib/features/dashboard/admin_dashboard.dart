// Admin dashboard (EX3): the project team's console — pending role approvals, a
// system summary, and links out to the two analytics surfaces. Summary-first;
// the depth lives on its own pages (never-cramp).
//
// See docs/ANKUR_EXPERIENCE_ROADMAP.md — EX3.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/features/dashboard/app_analytics_screen.dart';
import 'package:cgms_app/features/dashboard/dashboard_widgets.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.roleAdmin,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SampleChip(),
            ],
          ),
          DashSection(title: l10n.dashPendingApprovals),
          _ApprovalRow(
              name: 'Dr. Rekha', detail: 'Doctor · PHC Rampur', l10n: l10n),
          _ApprovalRow(
            name: 'Vikram S.',
            detail: 'Supervisor · Sitapur',
            l10n: l10n,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              DashStatTile(
                value: '42',
                label: l10n.dashCentres,
                color: const Color(0xFF4B5570),
              ),
              const SizedBox(width: 8),
              DashStatTile(
                value: '128',
                label: l10n.dashUsers,
                color: const Color(0xFF4B5570),
              ),
              const SizedBox(width: 8),
              DashStatTile(
                value: '91%',
                label: l10n.dashCoverage,
                color: const Color(0xFF2E7D32),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.insights),
              title: Text(l10n.dashProgramAnalytics),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: Text(l10n.dashAppAnalytics),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AppAnalyticsScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalRow extends StatelessWidget {
  const _ApprovalRow({
    required this.name,
    required this.detail,
    required this.l10n,
  });

  final String name;
  final String detail;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF4B5570).withValues(alpha: 0.15),
          child: Text(
            name.characters.first, // i18n-ignore: sample initial
            style: const TextStyle(color: Color(0xFF4B5570)),
          ),
        ),
        title: Text(name), // i18n-ignore: sample user name
        subtitle: Text(detail), // i18n-ignore: sample role/centre
        trailing: FilledButton.tonal(
          onPressed: () {},
          child: Text(l10n.dashApprove),
        ),
      ),
    );
  }
}
