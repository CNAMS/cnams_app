// Admin · App analytics (EX3): system health, not children — crash-free rate,
// API latency, error rate, sync health, active users by role, version spread.
//
// Sync backlog / dead-letter counts are REAL (from the outbox). The performance
// metrics are illustrative until backend telemetry / crash reporting lands (P6).
//
// See docs/ANKUR_EXPERIENCE_ROADMAP.md — EX3.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/features/dashboard/dashboard_widgets.dart';

class AppAnalyticsScreen extends ConsumerWidget {
  const AppAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final counts = ref.watch(outboxCountsProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dashAppAnalytics)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [SampleChip()],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                DashStatTile(
                  value: '99.4%',
                  label: l10n.dashCrashFree,
                  color: const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 8),
                DashStatTile(
                  value: '180ms',
                  label: l10n.dashApiLatency,
                  color: const Color(0xFF4B5570),
                ),
                const SizedBox(width: 8),
                DashStatTile(
                  value: '0.7%',
                  label: l10n.dashErrorRate,
                  color: const Color(0xFFC62828),
                ),
              ],
            ),
            DashSection(title: l10n.syncBacklog),
            // Real numbers from the outbox.
            Card(
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
            DashSection(title: l10n.dashActiveUsers),
            const _RoleBars(),
            DashSection(title: l10n.dashAppVersion),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'v0.4 · 92%    v0.3 · 8%', // i18n-ignore: sample versions
                  style:
                      TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
            ),
          ],
        ),
      ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          height: 90,
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
                        height: 70 * frac,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label, // i18n-ignore: short role code
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
