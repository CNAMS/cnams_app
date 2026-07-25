// Doctor dashboard (EX3): the inbox of referred SAM/MAM cases, each with the
// child, age, centre and severity, filterable by severity.
//
// Sample cases until referrals flow through the server; the real list reads the
// referrals + measurements already in the data layer once cases exist.
//
// See docs/ANKUR_EXPERIENCE_ROADMAP.md — EX3.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/features/dashboard/dashboard_widgets.dart';

class _Case {
  const _Case(this.name, this.age, this.centre, this.detail, this.severe);
  final String name;
  final String age;
  final String centre;
  final String detail;
  final bool severe; // true = SAM (red), false = MAM (amber)
}

const _cases = [
  _Case('आरव', '14 mo', 'AWC 214', 'WHZ −3.4', true),
  _Case('कबीर', '9 mo', 'AWC 207', 'MUAC 112 · oedema', true),
  _Case('दीया', '22 mo', 'AWC 207', 'WHZ −2.3', false),
  _Case('मीरा', '18 mo', 'AWC 233', 'WHZ −2.6', false),
];

class DoctorDashboard extends StatelessWidget {
  const DoctorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final samCount = _cases.where((c) => c.severe).length;
    final mamCount = _cases.length - samCount;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.dashReferredCases,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SampleChip(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SeverityPill(
                label: '${l10n.resultSam} · $samCount',
                color: const Color(0xFFC62828),
              ),
              const SizedBox(width: 8),
              _SeverityPill(
                label: '${l10n.resultMam} · $mamCount',
                color: const Color(0xFFE68A00),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final c in _cases) _CaseTile(c: c),
        ],
      ),
    );
  }
}

class _SeverityPill extends StatelessWidget {
  const _SeverityPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.c});
  final _Case c;

  @override
  Widget build(BuildContext context) {
    final color = c.severe ? const Color(0xFFC62828) : const Color(0xFFE68A00);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(
            c.name.characters.first, // i18n-ignore: sample child initial
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(c.name), // i18n-ignore: sample child name
        subtitle: Text(
          '${c.age} · ${c.centre} · ${c.detail}', // i18n-ignore: sample detail
        ),
        trailing: Icon(Icons.chevron_right, color: color),
      ),
    );
  }
}
