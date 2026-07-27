// Premium landing / welcome (U2): the first impression before the language
// choice. A soft botanical gradient, the Ankur sprout growing in, the wordmark
// and tagline, and a single "Get started" CTA. Shown first-run only.
//
// Rendered before a language is chosen, so it uses the default (Hindi) locale —
// Hindi-first by design.
//
// See docs/PREMIUM_UI_ROADMAP.md — U2.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/features/onboarding/sprout_mark.dart';
import 'package:cgms_app/shared/theme/design_tokens.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({required this.onGetStarted, super.key});

  final VoidCallback onGetStarted;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The welcome always wears the AWW/brand gradient — role isn't known yet.
    final gradient = roleGradient(AppRole.aww, Brightness.dark);
    const onGradient = Colors.white;

    final grow = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    final fade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.4, 1, curve: Curves.easeOut),
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              children: [
                const Spacer(flex: 3),
                // The sprout grows in with the launch motion.
                AnimatedBuilder(
                  animation: grow,
                  builder: (_, __) => SproutMark(
                    size: 120,
                    progress: grow.value,
                    stroke: onGradient,
                    leafLight: const Color(0xFF8FD3C6),
                    leafDark: const Color(0xFFB8E4C9),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FadeTransition(
                  opacity: fade,
                  child: Column(
                    children: [
                      Text(
                        l10n.appTitle,
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(
                              color: onGradient,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.welcomeTagline,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: onGradient.withValues(alpha: 0.92),
                            ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 4),
                FadeTransition(
                  opacity: fade,
                  child: Text(
                    l10n.welcomeIntro,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: onGradient.withValues(alpha: 0.82),
                        ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FadeTransition(
                  opacity: fade,
                  child: FilledButton(
                    onPressed: widget.onGetStarted,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF00695C),
                      minimumSize: const Size.fromHeight(58),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(l10n.welcomeGetStarted),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
