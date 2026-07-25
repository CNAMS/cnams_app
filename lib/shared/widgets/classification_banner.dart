import 'package:flutter/material.dart';

import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/shared/theme/app_theme.dart';

/// The colour band that fills the top of the Result screen.
///
/// This widget is the guardrail for the "never colour alone" rule: it always
/// draws the colour, the icon, and the caller-supplied word together, so no
/// screen can show a bare colour. The [label] is passed in already localised
/// (Hindi first) — this widget deliberately holds no strings of its own.
///
/// See docs/PRODUCTION_ROADMAP.md — the Result screen.
class ClassificationBanner extends StatelessWidget {
  const ClassificationBanner({
    required this.classification,
    required this.label,
    super.key,
  });

  final GrowthClass classification;

  /// Localised label, e.g. "गंभीर कुपोषण (SAM)".
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.styleFor(classification);
    return Semantics(
      label: label,
      container: true,
      child: Container(
        width: double.infinity,
        color: style.color,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, color: style.onColor, size: 72),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: style.onColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
