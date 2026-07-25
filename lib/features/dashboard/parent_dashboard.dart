// Parent dashboard (EX3): the parent's own child, front and centre — a plain-
// language status, the growth curve, next visit and the growth card.
//
// Shown as a sample child until parent↔child linking exists (an open decision —
// see the roadmap). The real screen reads the linked child's measurements from
// the existing data layer.
//
// See docs/ANKUR_EXPERIENCE_ROADMAP.md — EX3.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/features/dashboard/dashboard_widgets.dart';
import 'package:cgms_app/features/history/growth_series.dart';
import 'package:cgms_app/shared/theme/app_theme.dart';
import 'package:cgms_app/core/zscore/classification.dart';

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final normal = AppTheme.styleFor(GrowthClass.normal);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'आरव · Aarav', // i18n-ignore: sample child name
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SampleChip(),
            ],
          ),
          const SizedBox(height: 12),
          // Plain-language status banner — colour + word + icon.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: normal.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(normal.icon, color: normal.onColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.resultNormal,
                        style: TextStyle(
                          color: normal.onColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'आपका बच्चा अच्छी तरह बढ़ रहा है', // i18n-ignore: sample copy
                        style: TextStyle(
                          color: normal.onColor.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.historyGrowthCurve,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(height: 60, child: _Sparkline()),
                  const Divider(height: 24),
                  _kv('Weight', '9.5 kg'),
                  _kv('Age', '14 months'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text(
              'अगली मुलाक़ात', // i18n-ignore: sample copy
            ),
            trailing: const Text('15 Aug'), // i18n-ignore: sample date
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.badge_outlined),
            label: Text(l10n.parentCard),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k), // i18n-ignore: sample label
            Text(
              v, // i18n-ignore: sample value
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
}

/// A tiny upward growth trajectory.
class _Sparkline extends StatelessWidget {
  const _Sparkline();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _SparkPainter(Theme.of(context).colorScheme.primary),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.color);
  final Color color;

  static const _points = [
    CurvePoint(0, 0.20),
    CurvePoint(0.25, 0.35),
    CurvePoint(0.5, 0.5),
    CurvePoint(0.75, 0.68),
    CurvePoint(1, 0.82),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i < _points.length; i++) {
      final p = _points[i];
      final o = Offset(p.x * size.width, (1 - p.y) * size.height);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    final last = _points.last;
    canvas.drawCircle(
      Offset(last.x * size.width, (1 - last.y) * size.height),
      3,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.color != color;
}
