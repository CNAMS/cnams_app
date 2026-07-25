// Supervisor dashboard (EX3): the sector rollup — children screened, SAM/MAM
// counts, overdue centres and referral follow-up.
//
// Figures are illustrative (marked with a sample chip) until the multi-centre
// model and server aggregates are live — that's P5 + backend.
//
// See docs/ANKUR_EXPERIENCE_ROADMAP.md — EX3.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/features/dashboard/dashboard_widgets.dart';

class SupervisorDashboard extends StatelessWidget {
  const SupervisorDashboard({super.key});

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
                  l10n.dashSectorOverview,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SampleChip(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              DashStatTile(
                value: '486',
                label: l10n.dashScreened,
                color: const Color(0xFF2E7D32),
                icon: Icons.groups,
              ),
              const SizedBox(width: 8),
              DashStatTile(
                value: '9',
                label: l10n.resultSam,
                color: const Color(0xFFC62828),
                icon: Icons.error_outline,
              ),
              const SizedBox(width: 8),
              DashStatTile(
                value: '31',
                label: l10n.resultMam,
                color: const Color(0xFFE68A00),
                icon: Icons.warning_amber,
              ),
            ],
          ),
          DashSection(title: l10n.dashOverdueCentres),
          _CentreRow(name: 'AWC 207 · Rampur', overdue: 18, ok: false),
          _CentreRow(name: 'AWC 214 · Sitapur', overdue: 5, ok: true),
          _CentreRow(name: 'AWC 233 · Bansi', overdue: 12, ok: false),
          DashSection(title: l10n.dashReferralFollowup),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.dashAttended),
                      const Text(
                        '22 / 40',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(value: 22 / 40, minHeight: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CentreRow extends StatelessWidget {
  const _CentreRow({
    required this.name,
    required this.overdue,
    required this.ok,
  });

  final String name;
  final int overdue;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF2E7D32) : const Color(0xFFE68A00);
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(Icons.home_work_outlined, color: color, size: 20),
      ),
      title: Text(name), // i18n-ignore: sample centre name
      trailing: Text(
        '$overdue', // i18n-ignore: numeric count
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
