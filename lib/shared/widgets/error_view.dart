// A friendly, localised error state (R6).
//
// User-facing async screens should never render a raw exception string. This
// shows a calm Hindi-first message with an icon and an optional retry, while
// the raw [error] is sent to the debug log for developers — not the screen.
//
// See docs/REFINEMENT_ROADMAP.md — R6.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({this.error, this.onRetry, super.key});

  /// The underlying error — logged, never shown to the user.
  final Object? error;

  /// If provided, a "Try again" button runs it.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (error != null) {
      debugPrint('ErrorView: $error');
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.errorGeneric,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.errorGenericDetail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
