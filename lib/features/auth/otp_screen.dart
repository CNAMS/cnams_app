// OTP sign-in (EX2): enter a phone/email, get a code, verify it. Two steps in
// one screen. Against the mock backend the code is a fixed demo value.
//
// See docs/ANKUR_EXPERIENCE_ROADMAP.md — EX2.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/auth/auth_controller.dart';
import 'package:cgms_app/core/auth/auth_models.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({required this.channel, required this.role, super.key});

  final OtpChannel channel;
  final AppRole role;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _dest = TextEditingController();
  final _code = TextEditingController();
  OtpChallenge? _challenge;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _dest.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await ref
          .read(authControllerProvider.notifier)
          .requestOtp(widget.channel, _dest.text);
      setState(() => _challenge = challenge);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(_challenge!, _code.text, widget.role);
      // On success the session is set; leave this route to reveal the app.
      if (mounted) Navigator.of(context).pop();
    } on AuthException {
      setState(() {
        _error = l10n.otpWrong;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPhone = widget.channel == OtpChannel.phone;

    return Scaffold(
      appBar: AppBar(
        title: Text(isPhone ? l10n.signInPhoneOtp : l10n.signInEmailOtp),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_challenge == null) ...[
              TextField(
                controller: _dest,
                keyboardType:
                    isPhone ? TextInputType.phone : TextInputType.emailAddress,
                inputFormatters:
                    isPhone ? [FilteringTextInputFormatter.digitsOnly] : null,
                decoration: InputDecoration(
                  labelText: isPhone ? l10n.fieldPhone : l10n.fieldEmail,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_error != null) _errorText(context, _error!),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _send,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(l10n.sendCode),
              ),
            ] else ...[
              Text(l10n.otpSentTo(_challenge!.destination)),
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, letterSpacing: 8),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  labelText: l10n.otpEnterCode,
                  helperText: l10n.otpDemoHint,
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _verify,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(l10n.verify),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorText(BuildContext context, String message) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          message, // i18n-ignore: backend/diagnostic message
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
}
