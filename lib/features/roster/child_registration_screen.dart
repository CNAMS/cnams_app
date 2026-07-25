// Child registration + consent capture (FR-APP-15).
//
// Works fully offline: on save it calls ChildRepository.registerChild, which
// writes locally and queues the record for sync. The DOB-precision control is
// deliberately prominent, and choosing "estimated" surfaces a warning, because
// an approximate DOB propagates a large error into WAZ/HAZ and that must be
// visible rather than hidden. Phase P1.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/data/child_repository.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';

class ChildRegistrationScreen extends ConsumerStatefulWidget {
  const ChildRegistrationScreen({required this.centreId, super.key});

  final String centreId;

  @override
  ConsumerState<ChildRegistrationScreen> createState() =>
      _ChildRegistrationScreenState();
}

class _ChildRegistrationScreenState
    extends ConsumerState<ChildRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _guardian = TextEditingController();
  final _icdsId = TextEditingController();
  final _consentFormRef = TextEditingController();

  ChildSex? _sex;
  DateTime? _dob;
  DobPrecision _dobPrecision = DobPrecision.exact;
  ConsentStatus _consent = ConsentStatus.given;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _guardian.dispose();
    _icdsId.dispose();
    _consentFormRef.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 2, now.month),
      firstDate: DateTime(now.year - 6),
      lastDate: now,
      // Open in type-the-date mode: reaching a birth month a year or two back by
      // paging the calendar is painful, and rural DOBs are often typed anyway.
      // The calendar toggle is still available in the dialog.
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_sex == null || _dob == null) {
      // Field validators cover the text fields; these two are pickers.
      setState(() {});
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    await ref.read(childRepositoryProvider).registerChild(
          centreId: widget.centreId,
          name: _name.text.trim(),
          sex: _sex!,
          dob: _dob!,
          dobPrecision: _dobPrecision,
          consentStatus: _consent,
          guardianName: _emptyToNull(_guardian.text),
          icdsId: _emptyToNull(_icdsId.text),
          consentFormRef: _emptyToNull(_consentFormRef.text),
          consentRecordedAt: _consent == ConsentStatus.given ? now : null,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.childSaved)),
    );
    Navigator.of(context).pop();
  }

  static String? _emptyToNull(String s) => s.trim().isEmpty ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.registerTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.fieldName,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.validationNameRequired
                    : null,
              ),
              const SizedBox(height: 20),
              Text(l10n.fieldSex, style: _labelStyle(context)),
              const SizedBox(height: 8),
              SegmentedButton<ChildSex>(
                segments: [
                  ButtonSegment(
                      value: ChildSex.male, label: Text(l10n.sexMale)),
                  ButtonSegment(
                    value: ChildSex.female,
                    label: Text(l10n.sexFemale),
                  ),
                ],
                selected: _sex == null ? {} : {_sex!},
                emptySelectionAllowed: true,
                onSelectionChanged: (s) =>
                    setState(() => _sex = s.isEmpty ? null : s.first),
              ),
              if (_sex == null) _errorText(context, l10n.validationSexRequired),
              const SizedBox(height: 20),
              _DobField(
                dob: _dob,
                onTap: _pickDob,
                label: l10n.fieldDob,
                selectLabel: l10n.selectDate,
              ),
              if (_dob == null) _errorText(context, l10n.validationDobRequired),
              const SizedBox(height: 20),
              Text(l10n.fieldDobPrecision, style: _labelStyle(context)),
              const SizedBox(height: 8),
              SegmentedButton<DobPrecision>(
                segments: [
                  ButtonSegment(
                    value: DobPrecision.exact,
                    label: Text(l10n.dobExact),
                  ),
                  ButtonSegment(
                    value: DobPrecision.month,
                    label: Text(l10n.dobMonth),
                  ),
                  ButtonSegment(
                    value: DobPrecision.estimated,
                    label: Text(l10n.dobEstimated),
                  ),
                ],
                selected: {_dobPrecision},
                onSelectionChanged: (s) =>
                    setState(() => _dobPrecision = s.first),
              ),
              if (_dobPrecision == DobPrecision.estimated)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Color(0xFFF9A825)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l10n.dobEstimatedWarning)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _guardian,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.fieldGuardian,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _icdsId,
                decoration: InputDecoration(
                  labelText: l10n.fieldIcdsId,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Text(l10n.fieldConsent, style: _labelStyle(context)),
              const SizedBox(height: 8),
              SegmentedButton<ConsentStatus>(
                segments: [
                  ButtonSegment(
                    value: ConsentStatus.given,
                    label: Text(l10n.consentGiven),
                  ),
                  ButtonSegment(
                    value: ConsentStatus.none,
                    label: Text(l10n.consentNone),
                  ),
                ],
                selected: {_consent},
                onSelectionChanged: (s) => setState(() => _consent = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _consentFormRef,
                decoration: InputDecoration(
                  labelText: l10n.fieldConsentFormRef,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle? _labelStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium;

  Widget _errorText(BuildContext context, String message) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
}

class _DobField extends StatelessWidget {
  const _DobField({
    required this.dob,
    required this.onTap,
    required this.label,
    required this.selectLabel,
  });

  final DateTime? dob;
  final VoidCallback onTap;
  final String label;
  final String selectLabel;

  @override
  Widget build(BuildContext context) {
    final text = dob == null
        ? selectLabel
        : '${dob!.year}-${_two(dob!.month)}-${_two(dob!.day)}';
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(text),
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
