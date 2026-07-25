// Parent growth card PDF builder (FR-APP-11).
//
// Pure with respect to Flutter — it only touches the `pdf` package — so the byte
// output can be tested headlessly. The card leads with the colour band and the
// result word, mirrors the on-screen result, and phrases referral as advice.
//
// Font note: PDF core fonts are Latin-only, so Hindi glyphs need a
// Devanagari-capable font embedded. Callers pass one in ([base]/[bold]); the
// screen loads Noto Sans Devanagari via the printing package. Bundling that
// font for fully-offline use is a P6 offline-hardening task.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P3.

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Already-localised, display-ready content for the card.
class ParentCardData {
  const ParentCardData({
    required this.title,
    required this.childName,
    required this.ageLabel,
    required this.classificationLabel,
    required this.referralLine,
    required this.bandColor,
    this.rows = const [],
  });

  final String title;
  final String childName;
  final String ageLabel;
  final String classificationLabel;
  final String referralLine;
  final PdfColor bandColor;

  /// Label/value pairs, e.g. ("Weight", "7.20 kg").
  final List<(String, String)> rows;
}

Future<Uint8List> buildParentCardPdf(
  ParentCardData data, {
  pw.Font? base,
  pw.Font? bold,
}) {
  final theme = pw.ThemeData.withFont(
    base: base ?? pw.Font.helvetica(),
    bold: bold ?? pw.Font.helveticaBold(),
  );
  final doc = pw.Document(theme: theme);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(data.title, style: const pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 4),
          pw.Text(
            data.childName,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(data.ageLabel),
          pw.SizedBox(height: 16),
          // Colour band + result word — the top-of-card signal.
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            color: data.bandColor,
            child: pw.Text(
              data.classificationLabel,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          for (final (label, value) in data.rows)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text(label), pw.Text(value)],
              ),
            ),
          pw.SizedBox(height: 16),
          pw.Text(data.referralLine),
        ],
      ),
    ),
  );

  return doc.save();
}
