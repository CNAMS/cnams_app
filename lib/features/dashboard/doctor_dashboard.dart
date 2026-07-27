// Doctor dashboard (EX3), premium treatment (U5): the inbox of referred
// SAM/MAM cases, each with the child, age, centre and severity.
//
// Sample cases until referrals flow through the server; the real list reads the
// referrals + measurements already in the data layer once cases exist. The
// layout and components are production-ready.
//
// See docs/PREMIUM_UI_ROADMAP.md — U5.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/features/dashboard/dashboard_widgets.dart';
import 'package:cgms_app/shared/theme/design_tokens.dart';
import 'package:cgms_app/shared/widgets/premium.dart';

class _Case {
  const _Case(this.name, this.age, this.centre, this.detail, this.severe);
  final String name;
  final String age;
  final String centre;
  final String detail;
  final bool severe; // true = SAM (red), false = MAM (amber)
}

const _cases = [
  _Case('आरव', '14 mo', 'AWC 214', 'WHZ −3.4', true),
  _Case('कबीर', '9 mo', 'AWC 207', 'MUAC 112 · oedema', true),
  _Case('दीया', '22 mo', 'AWC 207', 'WHZ −2.3', false),
  _Case('मीरा', '18 mo', 'AWC 233', 'WHZ −2.6', false),
];

class DoctorDashboard extends StatelessWidget {
  const DoctorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final samCount = _cases.where((c) => c.severe).length;
    final mamCount = _cases.length - samCount;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GradientHeader(
          role: AppRole.doctor,
          title: l10n.dashReferredCases,
          trailing: const HeaderSampleTag(),
          bottom: Row(
            children: [
              _SeverityPill(
                label: '${l10n.resultSam} · $samCount',
                color: const Color(0xFFC62828),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SeverityPill(
                label: '${l10n.resultMam} · $mamCount',
                color: const Color(0xFFE68A00),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [for (final c in _cases) _CaseCard(c: c)],
          ),
        ),
      ],
    );
  }
}

class _SeverityPill extends StatelessWidget {
  const _SeverityPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.allPill,
      ),
      child: Text(
        label,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.c});
  final _Case c;

  @override
  Widget build(BuildContext context) {
    final color = c.severe ? const Color(0xFFC62828) : const Color(0xFFE68A00);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: PremiumCard(
        onTap: () {},
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // A severity stripe down the leading edge.
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(
                    left: AppRadius.lg,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Text(
                          // i18n-ignore: sample child initial
                          c.name.characters.first,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name, // i18n-ignore: sample child name
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              // i18n-ignore: sample detail
                              '${c.age} · ${c.centre} · ${c.detail}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: color),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
