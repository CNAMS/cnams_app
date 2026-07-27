// Admin dashboard (EX3), premium treatment (U6): the project team's console —
// pending role approvals, a system summary, and links out to the two analytics
// surfaces. Summary-first; the depth lives on its own pages (never-cramp).
//
// Sample figures until the identity/config server lands; the layout and
// components are production-ready.
//
// See docs/PREMIUM_UI_ROADMAP.md — U6.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/features/dashboard/app_analytics_screen.dart';
import 'package:cgms_app/features/dashboard/dashboard_widgets.dart';
import 'package:cgms_app/shared/theme/design_tokens.dart';
import 'package:cgms_app/shared/widgets/premium.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const slate = Color(0xFF4B5570);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GradientHeader(
          role: AppRole.admin,
          title: l10n.roleAdmin,
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
                      icon: Icons.home_work_outlined,
                      value: '42',
                      label: l10n.dashCentres,
                      color: slate,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MetricCard(
                      icon: Icons.people_outline,
                      value: '128',
                      label: l10n.dashUsers,
                      color: slate,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MetricCard(
                      icon: Icons.trending_up,
                      value: '91%',
                      label: l10n.dashCoverage,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              SectionTitle(title: l10n.dashPendingApprovals),
              PremiumCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  children: [
                    _ApprovalRow(
                      name: 'Dr. Rekha',
                      detail: 'Doctor · PHC Rampur',
                      l10n: l10n,
                    ),
                    const Divider(height: 1),
                    _ApprovalRow(
                      name: 'Vikram S.',
                      detail: 'Supervisor · Sitapur',
                      l10n: l10n,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _ConsoleLink(
                icon: Icons.insights,
                title: l10n.dashProgramAnalytics,
                color: slate,
                onTap: () {},
              ),
              const SizedBox(height: AppSpacing.md),
              _ConsoleLink(
                icon: Icons.monitor_heart_outlined,
                title: l10n.dashAppAnalytics,
                color: slate,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppAnalyticsScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConsoleLink extends StatelessWidget {
  const _ConsoleLink({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.allMd,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const Icon(Icons.chevron_right),
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
    return ListTile(
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
    );
  }
}
