// Child registration + consent capture (FR-APP-15), and editing (R2).
//
// Works fully offline: on save it calls ChildRepository.registerChild (create)
// or updateChild (edit), which write locally and queue the record for sync. The
// DOB-precision control is deliberately prominent, and choosing "estimated"
// surfaces a warning, because an approximate DOB propagates a large error into
// WAZ/HAZ and that must be visible rather than hidden.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/data/child_repository.dart';
import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';

class ChildRegistrationScreen extends ConsumerStatefulWidget {
  const ChildRegistrationScreen({
    required this.centreId,
    this.existing,
    super.key,
  });

  final String centreId;

  /// When non-null, the screen edits this child instead of creating one.
  final Child? existing;

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
  // DOB is entered as year/month/day dropdowns (the calendar's month picker was
  // unusable) — see docs/BUG_AUDIT.md. Day is optional; missing day means the
  // 1st, which pairs naturally with 'month' precision.
  int? _year;
  int? _month;
  int? _day;
  DobPrecision _dobPrecision = DobPrecision.exact;
  ConsentStatus _consent = ConsentStatus.given;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    if (c != null) {
      _name.text = c.name;
      _guardian.text = c.guardianName ?? '';
      _icdsId.text = c.icdsId ?? '';
      _consentFormRef.text = c.consentFormRef ?? '';
      _sex = ChildSex.fromDb(c.sex);
      _year = c.dob.year;
      _month = c.dob.month;
      _day = c.dob.day;
      _dobPrecision = DobPrecision.fromDb(c.dobPrecision);
      _consent = ConsentStatus.fromDb(c.consentStatus);
    }
  }

  DateTime? get _dob {
    if (_year == null || _month == null) return null;
    final day = (_day ?? 1).clamp(1, _daysInMonth(_year!, _month!));
    return DateTime(_year!, _month!, day);
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  @override
  void dispose() {
    _name.dispose();
    _guardian.dispose();
    _icdsId.dispose();
    _consentFormRef.dispose();
    super.dispose();
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
    final repo = ref.read(childRepositoryProvider);
    if (_isEditing) {
      await repo.updateChild(
        widget.existing!,
        name: _name.text.trim(),
        sex: _sex,
        dob: _dob,
        dobPrecision: _dobPrecision,
        guardianName: _emptyToNull(_guardian.text),
        icdsId: _emptyToNull(_icdsId.text),
        consentStatus: _consent,
        consentFormRef: _emptyToNull(_consentFormRef.text),
      );
    } else {
      await repo.registerChild(
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
    }

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
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editTitle : l10n.registerTitle),
      ),
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
              Text(l10n.fieldDob, style: _labelStyle(context)),
              const SizedBox(height: 8),
              _DobDropdowns(
                year: _year,
                month: _month,
                day: _day,
                onYear: (v) => setState(() => _year = v),
                onMonth: (v) => setState(() => _month = v),
                onDay: (v) => setState(() => _day = v),
                l10n: l10n,
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

/// Year / month / day dropdowns for the date of birth — unambiguous and easy
/// to reach a birth month/year, unlike paging the calendar. Day is optional.
class _DobDropdowns extends StatelessWidget {
  const _DobDropdowns({
    required this.year,
    required this.month,
    required this.day,
    required this.onYear,
    required this.onMonth,
    required this.onDay,
    required this.l10n,
  });

  final int? year;
  final int? month;
  final int? day;
  final ValueChanged<int?> onYear;
  final ValueChanged<int?> onMonth;
  final ValueChanged<int?> onDay;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final thisYear = DateTime.now().year;
    final years = [for (var y = thisYear; y >= thisYear - 6; y--) y];
    final maxDay = (year != null && month != null)
        ? DateTime(year!, month! + 1, 0).day
        : 31;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _Dd<int>(
            label: l10n.dobYear,
            value: year,
            items: years,
            text: (y) => '$y',
            onChanged: onYear,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _Dd<int>(
            label: l10n.dobMonth,
            value: month,
            items: [for (var m = 1; m <= 12; m++) m],
            text: (m) => m.toString().padLeft(2, '0'),
            onChanged: onMonth,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _Dd<int>(
            label: l10n.dobDay,
            value: (day != null && day! <= maxDay) ? day : null,
            items: [for (var d = 1; d <= maxDay; d++) d],
            text: (d) => '$d',
            onChanged: onDay,
          ),
        ),
      ],
    );
  }
}

class _Dd<T> extends StatelessWidget {
  const _Dd({
    required this.label,
    required this.value,
    required this.items,
    required this.text,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) text;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item,
            child: Text(text(item)), // i18n-ignore: numeric year/month/day
          ),
      ],
      onChanged: onChanged,
    );
  }
}
