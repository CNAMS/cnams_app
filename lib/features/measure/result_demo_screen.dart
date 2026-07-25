// A gallery of the Result banner for every classification band.
//
// Not a product screen — a visual reference so the "colour + word first,
// z-scores below the fold, referral as advice" design can be seen on a device
// during P0/P1 before the real capture flow exists. The real Result screen
// (FR-APP-7,9) is built in Phase P3.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/shared/widgets/classification_banner.dart';

class ResultDemoScreen extends StatelessWidget {
  const ResultDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String label(GrowthClass c) {
      switch (c) {
        case GrowthClass.normal:
          return l10n.resultNormal;
        case GrowthClass.mam:
          return l10n.resultMam;
        case GrowthClass.sam:
          return l10n.resultSam;
        case GrowthClass.overweight:
          return l10n.resultOverweight;
        case GrowthClass.indeterminate:
          return l10n.resultIndeterminate;
      }
    }

    return SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.resultDemoHint),
          ),
          for (final c in GrowthClass.values)
            _ResultCard(classification: c, label: label(c), l10n: l10n),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.classification,
    required this.label,
    required this.l10n,
  });

  final GrowthClass classification;
  final String label;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Colour + Hindi word + icon — the top half of the real screen.
          ClassificationBanner(classification: classification, label: label),
          // z-scores live below the fold, as numbers, deliberately secondary.
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ZRow(label: l10n.zScoreWeightForAge, value: '-1.8'),
                _ZRow(label: l10n.zScoreHeightForAge, value: '-2.3'),
                _ZRow(label: l10n.zScoreWeightForHeight, value: '-1.1'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l10n.referralAdvised)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZRow extends StatelessWidget {
  const _ZRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value, // i18n-ignore: numeric z-score value, not translatable copy
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
