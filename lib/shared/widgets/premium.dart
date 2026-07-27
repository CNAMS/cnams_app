// Premium shared components (U1): the building blocks every polished screen is
// composed from — a role-tinted gradient hero, a metric card, a soft-shadow
// surface, and a section title. Built on the design tokens so spacing, radius
// and depth are identical everywhere.
//
// See docs/PREMIUM_UI_ROADMAP.md — U1.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/shared/theme/design_tokens.dart';

/// A role-tinted gradient hero band at the top of a dashboard. Carries a
/// greeting/title, an optional subtitle, an optional leading badge (avatar or
/// logo) and optional trailing content (e.g. a headline number).
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    required this.role,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.bottom,
    super.key,
  });

  final AppRole role;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Optional content pinned below the title row (e.g. a row of chips).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final gradient = roleGradient(role, brightness);
    const onGradient = Colors.white;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(bottom: AppRadius.xl),
        boxShadow: AppShadows.lifted(brightness),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: onGradient,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle!,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: onGradient.withValues(alpha: 0.9),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  trailing!,
                ],
              ],
            ),
            if (bottom != null) ...[
              const SizedBox(height: AppSpacing.lg),
              bottom!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A soft-shadow surface — the premium replacement for a raw [Card].
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final content = Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppRadius.allLg,
        boxShadow: AppShadows.soft(theme.brightness),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.allLg,
      child: InkWell(
        borderRadius: AppRadius.allLg,
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// A single premium metric: an icon chip, a big tabular number, a label, and an
/// optional hint (e.g. "of 42"). Colour is always paired with the icon + label,
/// never used alone.
class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.hint,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: AppRadius.allMd,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              hint!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// A consistent section header with an optional trailing action ("see all").
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    this.action,
    super.key,
  });

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
