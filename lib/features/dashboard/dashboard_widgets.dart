// Shared dashboard building block: HeaderSampleTag — a "sample data" marker
// sized for a gradient hero, used where a surface shows representative figures
// until the multi-centre / referral data and backend telemetry are live (kept
// honest rather than passing sample numbers off as real). The premium metric
// and section widgets now live in shared/widgets/premium.dart.
//
// See docs/PREMIUM_UI_ROADMAP.md — U5/U6.

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
