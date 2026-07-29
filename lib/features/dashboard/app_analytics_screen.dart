// Admin · App analytics (EX3), premium treatment (U6): system health, not
// children — crash-free rate, API latency, error rate, sync health, active
// users by role, version spread.
//
// Sync backlog / dead-letter counts are REAL (from the outbox). The performance
// metrics are illustrative until backend telemetry / crash reporting lands (P6).
//
// See docs/PREMIUM_UI_ROADMAP.md — U6.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/shared/theme/design_tokens.dart';
import 'package:cgms_app/shared/widgets/premium.dart';

class AppAnalyticsScreen extends ConsumerWidget {
  const AppAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final counts = ref.watch(outboxCountsProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dashAppAnalytics)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          // Performance metrics are illustrative until telemetry lands.
          Align(
            alignment: Alignment.centerRight,
            child: _SampleTag(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MetricCard(
                  icon: Icons.shield_outlined,
                  value: '99.4%',
                  label: l10n.dashCrashFree,
                  color: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  icon: Icons.speed,
                  value: '180ms',
                  label: l10n.dashApiLatency,
                  color: const Color(0xFF4B5570),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  icon: Icons.report_gmailerrorred_outlined,
                  value: '0.7%',
                  label: l10n.dashErrorRate,
                  color: const Color(0xFFC62828),
                ),
              ),
            ],
          ),
          SectionTitle(title: l10n.syncBacklog),
          // Real numbers from the outbox.
          PremiumCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: Text(l10n.syncBacklog),
                  trailing: Text(
                    '${counts?.pending ?? 0}', // i18n-ignore: count
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(l10n.syncDeadLetter),
                  trailing: Text(
                    '${counts?.deadLetter ?? 0}', // i18n-ignore: count
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          SectionTitle(title: l10n.dashActiveUsers),
          const PremiumCard(child: _RoleBars()),
          SectionTitle(title: l10n.dashAppVersion),
          const PremiumCard(
            child: Text(
              'v0.4 · 92%    v0.3 · 8%', // i18n-ignore: sample versions
              style: TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

/// A muted "sample data" tag for a light surface (the app-bar body).
class _SampleTag extends StatelessWidget {
  const _SampleTag({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.science_outlined, size: 13, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          l10n.sampleData,
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }
}

class _RoleBars extends StatelessWidget {
  const _RoleBars();

  static const _data = [
    ('AWW', 0.85, Color(0xFF00695C)),
    ('Sup', 0.55, Color(0xFF2E7D32)),
    ('Doc', 0.40, Color(0xFF1565C0)),
    ('Par', 0.70, Color(0xFFE68A00)),
    ('Adm', 0.25, Color(0xFF4B5570)),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (label, frac, color) in _data)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    height: 74 * frac,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    label, // i18n-ignore: short role code
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
