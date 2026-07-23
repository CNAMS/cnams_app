// Child roster: search, filter by overdue, add a child (FR-APP-5).
//
// Reads the live roster stream (which works offline) and filters it in memory
// so search and the overdue toggle feel instant. Phase P1.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/data/child_repository.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/features/roster/child_registration_screen.dart';

class RosterScreen extends ConsumerStatefulWidget {
  const RosterScreen({super.key});

  @override
  ConsumerState<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends ConsumerState<RosterScreen> {
  String _query = '';
  bool _overdueOnly = false;

  List<RosterEntry> _filter(List<RosterEntry> all) {
    final q = _query.trim().toLowerCase();
    return all.where((e) {
      if (_overdueOnly && !e.isOverdue) return false;
      if (q.isEmpty) return true;
      final name = e.child.name.toLowerCase();
      final guardian = (e.child.guardianName ?? '').toLowerCase();
      return name.contains(q) || guardian.contains(q);
    }).toList(growable: false);
  }

  Future<void> _addChild() async {
    final centreId = await ref.read(currentCentreProvider.future);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChildRegistrationScreen(centreId: centreId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roster = ref.watch(rosterProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: l10n.rosterSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilterChip(
                  label: Text(l10n.rosterOnlyOverdue),
                  selected: _overdueOnly,
                  onSelected: (v) => setState(() => _overdueOnly = v),
                ),
              ),
            ),
            Expanded(
              child: roster.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('$e'), // i18n-ignore: diagnostic, not UI copy
                ),
                data: (all) {
                  final entries = _filter(all);
                  if (entries.isEmpty) {
                    return _EmptyState(
                      message: _overdueOnly
                          ? l10n.rosterEmptyOverdue
                          : l10n.rosterEmpty,
                    );
                  }
                  return ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) =>
                        _RosterTile(entry: entries[i], l10n: l10n),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addChild,
        icon: const Icon(Icons.person_add),
        label: Text(l10n.rosterAddChild),
      ),
    );
  }
}

class _RosterTile extends StatelessWidget {
  const _RosterTile({required this.entry, required this.l10n});

  final RosterEntry entry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final child = entry.child;
    final subtitle = entry.lastMeasuredAt == null
        ? l10n.rosterNeverMeasured
        : l10n.rosterLastMeasured(_fmtDate(entry.lastMeasuredAt!));

    return ListTile(
      leading: CircleAvatar(
        child: Text(child.name.isEmpty ? '?' : child.name.characters.first),
      ),
      title: Text(child.name),
      subtitle: Text(subtitle),
      trailing: entry.isOverdue
          ? Chip(
              label: Text(l10n.rosterOverdueBadge),
              visualDensity: VisualDensity.compact,
              backgroundColor: const Color(0xFFF9A825),
              side: BorderSide.none,
            )
          : null,
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';
  static String _two(int n) => n.toString().padLeft(2, '0');
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.child_care,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
