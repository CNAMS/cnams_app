// Email + password sign-in (EX2, fix #2): enter an email and password to sign
// in, or create the account on first use. Password is hashed by the (mock)
// backend, never sent or stored in the clear.
//
// See docs/BUG_AUDIT.md #2.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/auth/auth_controller.dart';
import 'package:cgms_app/core/auth/auth_models.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';

class PasswordScreen extends ConsumerStatefulWidget {
  const PasswordScreen({required this.role, super.key});

  final AppRole role;

  @override
  ConsumerState<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends ConsumerState<PasswordScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signInWithPassword(
            _email.text,
            _password.text,
            widget.role,
          );
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.signInPassword)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.fieldEmail,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: l10n.fieldPassword,
                helperText: l10n.passwordHint,
                errorText: _error,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  tooltip: _obscure
                      ? l10n.a11yShowPassword
                      : l10n.a11yHidePassword,
                  icon:
                      Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(l10n.passwordSignInAction),
            ),
          ],
        ),
      ),
    );
  }
}
