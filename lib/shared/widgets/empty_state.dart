// A friendly empty state (R4): the Ankur sprout above a single line, with an
// optional call to action. Shared so every "nothing here yet" screen reads the
// same — roster, history, referrals, centre.
//
// See docs/REFINEMENT_ROADMAP.md — R4.

import 'package:flutter/material.dart';

import 'package:cgms_app/features/onboarding/sprout_mark.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    this.detail,
    this.action,
    super.key,
  });

  /// The one-line headline, e.g. "No children yet".
  final String message;

  /// Optional second line with a gentle explanation.
  final String? detail;

  /// Optional call to action (e.g. an "Add child" button).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The sprout, tinted to sit quietly on the surface (its default
            // colours are tuned for the dark splash).
            SproutMark(
              size: 72,
              stroke: muted,
              leafLight: theme.colorScheme.primary.withValues(alpha: 0.55),
              leafDark: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
