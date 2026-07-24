// Parent card PDF builder test: produces a valid, non-trivial PDF document.

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

import 'package:cgms_app/features/history/parent_card.dart';

void main() {
  test('builds a non-empty PDF beginning with the %PDF header', () async {
    const data = ParentCardData(
      title: 'Child Growth Card',
      childName: 'Aarav',
      ageLabel: '16 months',
      classificationLabel: 'Moderate malnutrition (MAM)',
      referralLine: 'Showing this child to the ANM is advised',
      bandColor: PdfColor.fromInt(0xFFF9A825),
      rows: [('Weight', '7.20 kg'), ('Length', '80.0 cm')],
    );

    final bytes = await buildParentCardPdf(data);

    expect(bytes.length, greaterThan(500));
    // PDF files start with "%PDF".
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
