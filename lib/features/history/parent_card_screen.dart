// Parent growth card screen (FR-APP-11): preview, share (e.g. WhatsApp) and
// print, all provided by the printing package's PdfPreview toolbar.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P3.

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/features/history/parent_card.dart';
import 'package:cgms_app/shared/theme/app_theme.dart';

class ParentCardScreen extends StatelessWidget {
  const ParentCardScreen({
    required this.child,
    required this.measurement,
    required this.classificationLabel,
    required this.growthClass,
    super.key,
  });

  final Child child;
  final Measurement measurement;
  final String classificationLabel;
  final GrowthClass growthClass;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.parentCard)),
      body: PdfPreview(
        // The toolbar carries print and share; hide the debug/page controls.
        canChangePageFormat: false,
        canDebug: false,
        build: (format) async {
          final base = await PdfGoogleFonts.notoSansDevanagariRegular();
          final bold = await PdfGoogleFonts.notoSansDevanagariBold();
          return buildParentCardPdf(
            _data(l10n),
            base: base,
            bold: bold,
          );
        },
      ),
    );
  }

  ParentCardData _data(AppLocalizations l10n) {
    final m = measurement;
    final months = (m.ageDays / 30.4375).toStringAsFixed(1);
    final color = AppTheme.styleFor(growthClass).color;

    return ParentCardData(
      title: l10n.appTitle,
      childName: child.name,
      ageLabel: l10n.historyAgeMonths(months),
      classificationLabel: classificationLabel,
      referralLine: l10n.referralAdvised,
      bandColor: PdfColor.fromInt(color.toARGB32()),
      rows: [
        if (m.weightG != null)
          (
            l10n.captureStepWeight,
            '${(m.weightG! / 1000).toStringAsFixed(2)} ${l10n.unitKg}'
          ),
        if (m.lengthMm != null)
          (
            l10n.captureStepLength,
            '${(m.lengthMm! / 10).toStringAsFixed(1)} ${l10n.unitCm}'
          ),
        if (m.muacMm != null)
          (
            l10n.captureStepMuac,
            '${(m.muacMm! / 10).toStringAsFixed(1)} ${l10n.unitCm}'
          ),
      ],
    );
  }
}
