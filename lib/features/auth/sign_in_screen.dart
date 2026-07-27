// Sign-in (EX2): pick a role, then continue with Google, phone OTP or email
// OTP. Rendered in the language chosen on the previous screen. AWWs unlock
// offline with a PIN after the first sign-in (handled by the gate, not here).
//
// See docs/ANKUR_EXPERIENCE_ROADMAP.md — EX2.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/auth/auth_controller.dart';
import 'package:cgms_app/core/auth/auth_models.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/features/auth/otp_screen.dart';
import 'package:cgms_app/features/auth/password_screen.dart';
import 'package:cgms_app/features/auth/role_display.dart';
import 'package:cgms_app/features/onboarding/sprout_mark.dart';
import 'package:cgms_app/shared/theme/design_tokens.dart';
import 'package:cgms_app/shared/widgets/premium.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  AppRole _role = AppRole.aww;

  void _startOtp(OtpChannel channel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OtpScreen(channel: channel, role: _role),
      ),
    );
  }

  void _startPassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PasswordScreen(role: _role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // A role-tinted hero that recolours as you pick a role — the app
          // shows you its per-role identity before you even sign in.
          GradientHeader(
            role: _role,
            title: l10n.signIn,
            subtitle: l10n.welcomeTagline,
            leading: const SproutMark(
              size: 44,
              stroke: Colors.white,
              leafLight: Color(0xFF8FD3C6),
              leafDark: Color(0xFFB8E4C9),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.whoAreYou,
                              style: theme.textTheme.labelLarge),
                          const SizedBox(height: AppSpacing.md),
                          _RoleGrid(
                            selected: _role,
                            onSelect: (r) => setState(() => _role = r),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      onPressed: () => ref
                          .read(authControllerProvider.notifier)
                          .signInWithGoogle(_role),
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: Text(l10n.continueWithGoogle),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _startOtp(OtpChannel.phone),
                            icon: const Icon(Icons.phone_android),
                            label: Text(l10n.signInPhoneOtp),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _startOtp(OtpChannel.email),
                            icon: const Icon(Icons.alternate_email),
                            label: Text(l10n.signInEmailOtp),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: _startPassword,
                      icon: const Icon(Icons.password),
                      label: Text(l10n.signInPassword),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 15,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            l10n.signInPinNote,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleGrid extends StatelessWidget {
  const _RoleGrid({required this.selected, required this.onSelect});

  final AppRole selected;
  final ValueChanged<AppRole> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final role in AppRole.values)
          _RoleChip(
            role: role,
            label: roleLabel(l10n, role),
            selected: role == selected,
            onTap: () => onSelect(role),
          ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.role,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppRole role;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(role);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : null,
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(roleIcon(role), size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
