// Parent dashboard (EX3), premium treatment (U5): the parent's own child, front
// and centre — a plain-language status, the growth curve, next visit.
//
// Shown as a sample child until parent↔child linking exists (an open decision —
// see the roadmap). The real screen reads the linked child's measurements from
// the existing data layer. The layout and components are production-ready.
//
// See docs/PREMIUM_UI_ROADMAP.md — U5.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/features/dashboard/dashboard_widgets.dart';
import 'package:cgms_app/features/history/growth_series.dart';
import 'package:cgms_app/shared/theme/app_theme.dart';
import 'package:cgms_app/shared/theme/design_tokens.dart';
import 'package:cgms_app/shared/widgets/premium.dart';

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final normal = AppTheme.styleFor(GrowthClass.normal);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const GradientHeader(
          role: AppRole.parent,
          title: 'आरव · Aarav', // i18n-ignore: sample child name
          subtitle: '14 months · AWC 214', // i18n-ignore: sample detail
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white24,
            child: Text(
              'आ', // i18n-ignore: sample child initial
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          trailing: HeaderSampleTag(),
        ),
        Reveal(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Plain-language status — colour + word + icon, reassuring.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: normal.color,
                    borderRadius: AppRadius.allLg,
                    boxShadow: AppShadows.soft(theme.brightness),
                  ),
                  child: Row(
                    children: [
                      Icon(normal.icon, color: normal.onColor, size: 32),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.resultNormal,
                              style: TextStyle(
                                color: normal.onColor,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              // i18n-ignore: sample copy
                              'आपका बच्चा अच्छी तरह बढ़ रहा है',
                              style: TextStyle(
                                color: normal.onColor.withValues(alpha: 0.92),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.historyGrowthCurve,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const SizedBox(height: 64, child: _Sparkline()),
                      const Divider(height: AppSpacing.xxl),
                      _kv('Weight', '9.5 kg'),
                      _kv('Age', '14 months'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
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
                            Icon(Icons.event, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'अगली मुलाक़ात', // i18n-ignore: sample copy
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const Text('15 Aug'), // i18n-ignore: sample date
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.badge_outlined),
                  label: Text(l10n.parentCard),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
    // A soft fill under the line for a touch more presence.
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));
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
      3.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.color != color;
}
