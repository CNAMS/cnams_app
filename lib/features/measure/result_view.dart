// The Result as a reusable, first-class piece of UI (R3).
//
// Colour band + word first (the AWW reads the classification at a glance),
// the three z-scores below, and a "referral advised" note for SAM/MAM. The
// capture flow embeds this with a Save action; the history embeds it (via
// ResultScreen) with a raise-referral action. The widget holds no navigation
// or persistence of its own — callers supply the [footer] actions — so the
// same result reads identically wherever it appears.
//
// See docs/REFINEMENT_ROADMAP.md — R3.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/features/referral/referral_ui.dart';
import 'package:cgms_app/shared/widgets/classification_banner.dart';

/// Maps a [GrowthClass] to its localised (Hindi-first) label.
String growthClassLabel(AppLocalizations l10n, GrowthClass c) => switch (c) {
      GrowthClass.normal => l10n.resultNormal,
      GrowthClass.mam => l10n.resultMam,
      GrowthClass.sam => l10n.resultSam,
      GrowthClass.overweight => l10n.resultOverweight,
      GrowthClass.indeterminate => l10n.resultIndeterminate,
    };

class ResultView extends StatelessWidget {
  const ResultView({
    required this.classification,
    required this.waz,
    required this.haz,
    required this.whz,
    this.footer,
    super.key,
  });

  final GrowthClass classification;
  final double? waz;
  final double? haz;
  final double? whz;

  /// Action area pinned below the scrolling z-scores (Save, Refer, …).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final referralAdvised = classification == GrowthClass.sam ||
        classification == GrowthClass.mam;

    return Column(
      children: [
        ClassificationBanner(
          classification: classification,
          label: growthClassLabel(l10n, classification),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ZRow(label: l10n.zScoreWeightForAge, z: waz),
              const Divider(height: 1),
              _ZRow(label: l10n.zScoreHeightForAge, z: haz),
              const Divider(height: 1),
              _ZRow(label: l10n.zScoreWeightForHeight, z: whz),
              if (classification == GrowthClass.indeterminate)
                _Note(icon: Icons.help_outline, text: l10n.resultIndeterminate),
              if (referralAdvised)
                _Note(
                  icon: Icons.info_outline,
                  text: l10n.referralAdvised,
                  emphasise: true,
                ),
            ],
          ),
        ),
        if (footer != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: footer,
            ),
          ),
      ],
    );
  }
}

/// A saved measurement's result as a standalone screen, opened from the
/// history's latest banner. Reuses [ResultView] and offers a raise-referral
/// call to action for SAM/MAM (feeds the R1 referral flow).
class ResultScreen extends ConsumerWidget {
  const ResultScreen({required this.measurement, super.key});

  final Measurement measurement;

  GrowthClass get _class => GrowthClass.values.firstWhere(
        (c) => c.name == measurement.classification,
        orElse: () => GrowthClass.indeterminate,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final growthClass = _class;
    final referralAdvised =
        growthClass == GrowthClass.sam || growthClass == GrowthClass.mam;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.resultTitle)),
      body: ResultView(
        classification: growthClass,
        waz: measurement.waz,
        haz: measurement.haz,
        whz: measurement.whz,
        footer: referralAdvised
            ? FilledButton.icon(
                onPressed: () =>
                    raiseReferral(context, ref, measurement.id),
                icon: const Icon(Icons.assignment_ind_outlined),
                label: Text(l10n.referralRaise),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              )
            : null,
      ),
    );
  }
}

class _ZRow extends StatelessWidget {
  const _ZRow({required this.label, required this.z});

  final String label;
  final double? z;

  @override
  Widget build(BuildContext context) {
    final z = this.z;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          Text(
            z == null ? '—' : z.toStringAsFixed(2), // i18n-ignore: numeric
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.text,
    this.emphasise = false,
  });

  final IconData icon;
  final String text;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasise
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
