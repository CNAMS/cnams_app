// Supervisor dashboard (EX3), premium treatment (U5): the sector rollup —
// children screened, SAM/MAM counts, overdue centres and referral follow-up.
//
// Figures are illustrative (marked with a sample chip) until the multi-centre
// model and server aggregates are live — that's P5 + backend. The layout and
// components are production-ready; only the data source is a placeholder.
//
// See docs/PREMIUM_UI_ROADMAP.md — U5.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/features/dashboard/dashboard_widgets.dart';
import 'package:cgms_app/shared/theme/design_tokens.dart';
import 'package:cgms_app/shared/widgets/premium.dart';

class SupervisorDashboard extends StatelessWidget {
  const SupervisorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GradientHeader(
          role: AppRole.supervisor,
          title: l10n.dashSectorOverview,
          trailing: const HeaderSampleTag(),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MetricCard(
                      icon: Icons.groups,
                      value: '486',
                      label: l10n.dashScreened,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MetricCard(
                      icon: Icons.error_outline,
                      value: '9',
                      label: l10n.resultSam,
                      color: const Color(0xFFC62828),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MetricCard(
                      icon: Icons.warning_amber,
                      value: '31',
                      label: l10n.resultMam,
                      color: const Color(0xFFE68A00),
                    ),
                  ),
                ],
              ),
              SectionTitle(title: l10n.dashOverdueCentres),
              const PremiumCard(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  children: [
                    _CentreRow(name: 'AWC 207 · Rampur', overdue: 18, ok: false),
                    _CentreRow(name: 'AWC 214 · Sitapur', overdue: 5, ok: true),
                    _CentreRow(name: 'AWC 233 · Bansi', overdue: 12, ok: false),
                  ],
                ),
              ),
              SectionTitle(title: l10n.dashReferralFollowup),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.dashAttended),
                        const Text(
                          '22 / 40', // i18n-ignore: numeric ratio
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const ClipRRect(
                      borderRadius: AppRadius.allPill,
                      child: LinearProgressIndicator(
                        value: 22 / 40,
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
