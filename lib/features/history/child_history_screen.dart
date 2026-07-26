// Child history hub (FR-APP-10): latest result, a weight-for-age growth curve,
// and the list of previous visits, with a button to take a new measurement.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P3.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/core/zscore/reference_tables.dart';
import 'package:cgms_app/features/history/growth_chart.dart';
import 'package:cgms_app/features/history/growth_series.dart';
import 'package:cgms_app/features/history/parent_card_screen.dart';
import 'package:cgms_app/features/measure/capture_flow_screen.dart';
import 'package:cgms_app/features/measure/result_view.dart';
import 'package:cgms_app/features/referral/referral_ui.dart';
import 'package:cgms_app/features/roster/child_registration_screen.dart';
import 'package:cgms_app/shared/theme/app_theme.dart';
import 'package:cgms_app/shared/widgets/empty_state.dart';

class ChildHistoryScreen extends ConsumerWidget {
  const ChildHistoryScreen({required this.child, super.key});

  final Child child;

  GrowthClass _classOf(String? name) => GrowthClass.values.firstWhere(
        (c) => c.name == name,
        orElse: () => GrowthClass.indeterminate,
      );

  String _label(AppLocalizations l10n, GrowthClass c) => switch (c) {
        GrowthClass.normal => l10n.resultNormal,
        GrowthClass.mam => l10n.resultMam,
        GrowthClass.sam => l10n.resultSam,
        GrowthClass.overweight => l10n.resultOverweight,
        GrowthClass.indeterminate => l10n.resultIndeterminate,
      };

  // Consent-withdrawal path: confirm, then soft-delete + queue a server delete,
  // and leave the screen (the child drops off the roster).
  Future<void> _withdrawConsent(
    BuildContext context,
    WidgetRef ref,
    Child child,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.withdrawConsent),
        content: Text(l10n.withdrawConsentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.withdrawConsent),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(childRepositoryProvider).withdrawConsent(child.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final measurements = ref.watch(measurementsProvider(child.id));
    final tables = ref.watch(referenceTablesProvider).valueOrNull;

    final rowsValue = measurements.valueOrNull;
    final latest =
        (rowsValue != null && rowsValue.isNotEmpty) ? rowsValue.first : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(child.name), // i18n-ignore: the child's own name
        actions: [
          if (latest != null)
            IconButton(
              tooltip: l10n.parentCard,
              icon: const Icon(Icons.badge_outlined),
              onPressed: () {
                final growthClass = _classOf(latest.classification);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ParentCardScreen(
                      child: child,
                      measurement: latest,
                      classificationLabel: _label(l10n, growthClass),
                      growthClass: growthClass,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            tooltip: l10n.editTitle,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChildRegistrationScreen(
                  centreId: child.centreId,
                  existing: child,
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'withdraw') _withdrawConsent(context, ref, child);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'withdraw',
                child: Text(l10n.withdrawConsent),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CaptureFlowScreen(child: child),
          ),
        ),
        icon: const Icon(Icons.straighten),
        label: Text(l10n.newMeasurement),
      ),
      body: measurements.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')), // i18n-ignore: diagnostic
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyState(
              message: l10n.historyNoVisits,
              action: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CaptureFlowScreen(child: child),
                  ),
                ),
                icon: const Icon(Icons.straighten),
                label: Text(l10n.newMeasurement),
              ),
            );
          }
          final latest = rows.first; // newest first
          final latestClass = _classOf(latest.classification);

          final childPoints = [
            for (final m in rows)
              if (m.weightG != null)
                CurvePoint(m.ageDays.toDouble(), m.weightG! / 1000),
          ];
          final bands = bandsFor(
            tables?.table(
              GrowthIndicator.weightForAge,
              child.sex == 'M' ? Sex.male : Sex.female,
            ),
          );

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              _LatestBanner(
                classification: latestClass,
                label: _label(l10n, latestClass),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ResultScreen(measurement: latest),
                  ),
                ),
              ),
              // Referral is advised for SAM/MAM — the worker acts on it.
              if (latestClass == GrowthClass.sam ||
                  latestClass == GrowthClass.mam)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: FilledButton.tonalIcon(
                    onPressed: () => raiseReferral(context, ref, latest.id),
                    icon: const Icon(Icons.assignment_ind_outlined),
                    label: Text(l10n.referralRaise),
                  ),
                ),
              _Section(title: l10n.historyGrowthCurve),
              SizedBox(
                height: 260,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: GrowthChart(
                    childPoints: childPoints,
                    bands: bands,
                    lineColor: AppTheme.styleFor(latestClass).color,
                  ),
                ),
              ),
              _Section(title: l10n.referralsSection),
              ReferralsList(childId: child.id),
              _Section(title: l10n.historyPreviousVisits),
              for (final m in rows)
                _VisitTile(
                  measurement: m,
                  l10n: l10n,
                  label: _label(l10n, _classOf(m.classification)),
                  growthClass: _classOf(m.classification),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LatestBanner extends StatelessWidget {
  const _LatestBanner({
    required this.classification,
    required this.label,
    this.onTap,
  });

  final GrowthClass classification;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.styleFor(classification);
    return Material(
      color: style.color,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              Icon(style.icon, color: style.onColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: style.onColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: style.onColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _VisitTile extends StatelessWidget {
  const _VisitTile({
    required this.measurement,
    required this.l10n,
    required this.label,
    required this.growthClass,
  });

  final Measurement measurement;
  final AppLocalizations l10n;
  final String label;
  final GrowthClass growthClass;

  @override
  Widget build(BuildContext context) {
    final m = measurement;
    final style = AppTheme.styleFor(growthClass);
    final months = (m.ageDays / 30.4375).toStringAsFixed(1);
    final parts = <String>[
      if (m.weightG != null)
        '${(m.weightG! / 1000).toStringAsFixed(2)} ${l10n.unitKg}',
      if (m.lengthMm != null)
        '${(m.lengthMm! / 10).toStringAsFixed(1)} ${l10n.unitCm}',
    ];

    return ListTile(
      leading: Icon(style.icon, color: style.color),
      title: Text(label),
      subtitle: Text(
        // i18n-ignore: composed of localized age + numeric measurements
        '${l10n.historyAgeMonths(months)} · ${parts.join(' · ')}',
      ),
      trailing: Text(
        _fmtDate(m.measuredAt), // i18n-ignore: numeric date
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';
  static String _two(int n) => n.toString().padLeft(2, '0');
}
