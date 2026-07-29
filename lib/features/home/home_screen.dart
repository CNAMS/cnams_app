// Home / centre dashboard (FR-APP-17), premium treatment (U4).
//
// A role-tinted gradient hero, then three live metric cards read from the real
// roster (centreStatsProvider) — no more sample numbers — a prominent
// "New measurement" call to action, and a live sync-backlog card.
//
// See docs/PREMIUM_UI_ROADMAP.md — U4.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/features/roster/roster_screen.dart';
import 'package:cgms_app/shared/theme/design_tokens.dart';
import 'package:cgms_app/shared/widgets/premium.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stats = ref.watch(centreStatsProvider);
    final pending = ref.watch(outboxCountsProvider).valueOrNull?.pending ?? 0;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GradientHeader(
          role: AppRole.aww,
          title: l10n.homeGreeting,
          subtitle: l10n.homeSubtitle,
        ),
        Reveal(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live metrics from the real roster — colour always paired with
                // an icon and a label.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: MetricCard(
                        icon: Icons.check_circle_outline,
                        value: '${stats.screenedThisMonth}',
                        label: l10n.screenedToday,
                        color: const Color(0xFF2E7D32),
                        hint: l10n.centreScreenedThisMonth,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: MetricCard(
                        icon: Icons.flag_outlined,
                        value: '${stats.flagged}',
                        label: l10n.flaggedCount,
                        color: const Color(0xFFC62828),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: MetricCard(
                        icon: Icons.schedule,
                        value: '${stats.overdue}',
                        label: l10n.overdueCount,
                        color: const Color(0xFFF9A825),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RosterScreen(),
                    ),
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
                const SizedBox(height: AppSpacing.lg),
                PremiumCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: AppRadius.allMd,
                        ),
                        child:
                            Icon(Icons.sync, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          l10n.syncBacklog,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        '$pending', // i18n-ignore: live count
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
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
