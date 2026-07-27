// Shared building blocks for the role dashboards: a stat tile, a section
// header, and a "sample data" chip (used where a surface shows representative
// figures until the multi-centre / referral data and backend telemetry are
// live — kept honest rather than passing sample numbers off as real).
//
// See docs/ANKUR_EXPERIENCE_ROADMAP.md — EX3.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/shared/theme/design_tokens.dart';

/// A translucent "sample data" tag sized to sit on a gradient hero (white on
/// the wash), for dashboards whose figures are illustrative until the server
/// aggregates land. Kept honest rather than passing sample numbers off as real.
class HeaderSampleTag extends StatelessWidget {
  const HeaderSampleTag({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: AppRadius.allPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.science_outlined, size: 13, color: Colors.white),
          const SizedBox(width: AppSpacing.xs),
          Text(
            l10n.sampleData,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// A compact metric tile: big number, small label, tinted by [color].
class DashStatTile extends StatelessWidget {
  const DashStatTile({
    required this.value,
    required this.label,
    required this.color,
    this.icon,
    super.key,
  });

  final String value;
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class DashSection extends StatelessWidget {
  const DashSection({required this.title, this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A small chip marking a surface (or figure) as illustrative sample data.
class SampleChip extends StatelessWidget {
  const SampleChip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.science_outlined, size: 13),
          const SizedBox(width: 4),
          Text(l10n.sampleData, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
