// Referral UI (R1): a "refer to" picker, an outcome picker, and a list of a
// child's referrals with a record-outcome action. Used from the child history.
//
// See docs/REFINEMENT_ROADMAP.md — R1.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/data/referral_repository.dart';
import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';

String outcomeLabel(AppLocalizations l10n, ReferralOutcome o) => switch (o) {
      ReferralOutcome.pending => l10n.outcomePending,
      ReferralOutcome.attended => l10n.outcomeAttended,
      ReferralOutcome.notAttended => l10n.outcomeNotAttended,
      ReferralOutcome.unknown => l10n.outcomeUnknown,
    };

Color outcomeColor(ReferralOutcome o) => switch (o) {
      ReferralOutcome.pending => const Color(0xFFE68A00),
      ReferralOutcome.attended => const Color(0xFF2E7D32),
      ReferralOutcome.notAttended => const Color(0xFFC62828),
      ReferralOutcome.unknown => const Color(0xFF6B6B6B),
    };

/// Ask where to refer, then raise the referral for [measurementId].
Future<void> raiseReferral(
  BuildContext context,
  WidgetRef ref,
  String measurementId,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showModalBottomSheet<ReferredTo>(
    context: context,
    builder: (_) => _PickerSheet<ReferredTo>(
      title: l10n.referralTo,
      options: {for (final r in ReferredTo.values) r: r.db},
    ),
  );
  if (choice == null) return;
  await ref
      .read(referralRepositoryProvider)
      .raise(measurementId: measurementId, referredTo: choice);
  messenger.showSnackBar(SnackBar(content: Text(l10n.referralRaised)));
}

/// Ask for the follow-up outcome, then record it for [referralId].
Future<void> recordReferralOutcome(
  BuildContext context,
  WidgetRef ref,
  String referralId,
) async {
  final l10n = AppLocalizations.of(context)!;
  final choice = await showModalBottomSheet<ReferralOutcome>(
    context: context,
    builder: (_) => _PickerSheet<ReferralOutcome>(
      title: l10n.referralRecordOutcome,
      options: {
        for (final o in ReferralOutcome.values)
          if (o != ReferralOutcome.pending) o: outcomeLabel(l10n, o),
      },
    ),
  );
  if (choice == null) return;
  await ref.read(referralRepositoryProvider).recordOutcome(referralId, choice);
}

/// A child's referrals with their outcome and a record-outcome action.
class ReferralsList extends ConsumerWidget {
  const ReferralsList({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final referrals = ref.watch(referralsProvider(childId)).valueOrNull ?? [];
    if (referrals.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final r in referrals) _ReferralTile(referral: r, l10n: l10n),
      ],
    );
  }
}

class _ReferralTile extends ConsumerWidget {
  const _ReferralTile({required this.referral, required this.l10n});

  final Referral referral;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ReferralOutcome.fromDb(referral.outcome);
    final color = outcomeColor(outcome);
    return ListTile(
      leading: Icon(Icons.assignment_turned_in_outlined, color: color),
      title: Text(l10n.referralReferredTo(referral.referredTo ?? '—')),
      subtitle: Text(
        _fmtDate(referral.referredAt), // i18n-ignore: numeric date
      ),
      trailing: outcome == ReferralOutcome.pending
          ? TextButton(
              onPressed: () => recordReferralOutcome(context, ref, referral.id),
              child: Text(l10n.referralRecordOutcome),
            )
          : Chip(
              label: Text(outcomeLabel(l10n, outcome)),
              backgroundColor: color.withValues(alpha: 0.15),
              side: BorderSide.none,
            ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({required this.title, required this.options});

  final String title;
  final Map<T, String> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final entry in options.entries)
            ListTile(
              title: Text(entry.value),
              onTap: () => Navigator.of(context).pop(entry.key),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
