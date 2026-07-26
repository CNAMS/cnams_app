// Child roster: search, filter by overdue, sort, add a child (FR-APP-5).
//
// Reads the live roster stream (which works offline) and filters/sorts it in
// memory so search, the overdue toggle and the sort feel instant. Phase P1;
// sort + latest-result badge + pull-to-refresh + clear button added in R4.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/data/child_repository.dart';
import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/core/zscore/classification.dart';
import 'package:cgms_app/features/history/child_history_screen.dart';
import 'package:cgms_app/features/measure/result_view.dart' show growthClassLabel;
import 'package:cgms_app/features/roster/child_registration_screen.dart';
import 'package:cgms_app/shared/theme/app_theme.dart';
import 'package:cgms_app/shared/widgets/empty_state.dart';
import 'package:cgms_app/shared/widgets/error_view.dart';

/// How the roster is ordered. Overdue/flagged-first put the children who need
/// attention at the top; name is the calm default.
enum RosterSort { name, overdue, flagged }

class RosterScreen extends ConsumerStatefulWidget {
  const RosterScreen({super.key});

  @override
  ConsumerState<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends ConsumerState<RosterScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _overdueOnly = false;
  RosterSort _sort = RosterSort.name;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RosterEntry> _filterAndSort(List<RosterEntry> all) {
    final q = _query.trim().toLowerCase();
    final list = all.where((e) {
      if (_overdueOnly && !e.isOverdue) return false;
      if (q.isEmpty) return true;
      final name = e.child.name.toLowerCase();
      final guardian = (e.child.guardianName ?? '').toLowerCase();
      return name.contains(q) || guardian.contains(q);
    }).toList();

    int byName(RosterEntry a, RosterEntry b) =>
        a.child.name.toLowerCase().compareTo(b.child.name.toLowerCase());

    switch (_sort) {
      case RosterSort.name:
        list.sort(byName);
      case RosterSort.overdue:
        list.sort((a, b) {
          if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
          return byName(a, b);
        });
      case RosterSort.flagged:
        list.sort((a, b) {
          if (a.isFlagged != b.isFlagged) return a.isFlagged ? -1 : 1;
          return byName(a, b);
        });
    }
    return list;
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

  void _openChild(Child child) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChildHistoryScreen(child: child),
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
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: l10n.rosterSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: l10n.a11yClearSearch,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  FilterChip(
                    label: Text(l10n.rosterOnlyOverdue),
                    selected: _overdueOnly,
                    onSelected: (v) => setState(() => _overdueOnly = v),
                  ),
                  const Spacer(),
                  _SortMenu(
                    sort: _sort,
                    l10n: l10n,
                    onChanged: (s) => setState(() => _sort = s),
                  ),
                ],
              ),
            ),
            Expanded(
              child: roster.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(rosterProvider),
                ),
                data: (all) {
                  final entries = _filterAndSort(all);
                  if (entries.isEmpty) {
                    return EmptyState(
                      message: _overdueOnly
                          ? l10n.rosterEmptyOverdue
                          : l10n.rosterEmpty,
                      action: _overdueOnly
                          ? null
                          : FilledButton.icon(
                              onPressed: _addChild,
                              icon: const Icon(Icons.person_add),
                              label: Text(l10n.rosterAddChild),
                            ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(rosterProvider),
                    child: ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _RosterTile(
                        entry: entries[i],
                        l10n: l10n,
                        onTap: () => _openChild(entries[i].child),
                      ),
                    ),
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

class _SortMenu extends StatelessWidget {
  const _SortMenu({
    required this.sort,
    required this.l10n,
    required this.onChanged,
  });

  final RosterSort sort;
  final AppLocalizations l10n;
  final ValueChanged<RosterSort> onChanged;

  String _label(RosterSort s) => switch (s) {
        RosterSort.name => l10n.rosterSortName,
        RosterSort.overdue => l10n.rosterSortOverdue,
        RosterSort.flagged => l10n.rosterSortFlagged,
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<RosterSort>(
      initialValue: sort,
      onSelected: onChanged,
      tooltip: l10n.rosterSort,
      icon: const Icon(Icons.sort),
      itemBuilder: (_) => [
        for (final s in RosterSort.values)
          PopupMenuItem(value: s, child: Text(_label(s))),
      ],
    );
  }
}

class _RosterTile extends StatelessWidget {
  const _RosterTile({
    required this.entry,
    required this.l10n,
    required this.onTap,
  });

  final RosterEntry entry;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  GrowthClass? get _lastClass {
    final name = entry.lastClassification;
    if (name == null) return null;
    return GrowthClass.values.firstWhere(
      (c) => c.name == name,
      orElse: () => GrowthClass.indeterminate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = entry.child;
    final subtitle = entry.lastMeasuredAt == null
        ? l10n.rosterNeverMeasured
        : l10n.rosterLastMeasured(_fmtDate(entry.lastMeasuredAt!));
    final lastClass = _lastClass;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Text(child.name.isEmpty ? '?' : child.name.characters.first),
      ),
      title: Text(child.name),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The latest classification, shown as colour + icon (never colour
          // alone) so a flagged child reads at a glance from the list. The
          // icon carries a semantics label so it isn't silent to a reader.
          if (lastClass != null && lastClass != GrowthClass.indeterminate)
            Semantics(
              label: growthClassLabel(l10n, lastClass),
              child: Icon(
                AppTheme.styleFor(lastClass).icon,
                color: AppTheme.styleFor(lastClass).color,
              ),
            ),
          if (entry.isOverdue) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text(l10n.rosterOverdueBadge),
              visualDensity: VisualDensity.compact,
              backgroundColor: const Color(0xFFF9A825),
              side: BorderSide.none,
            ),
          ],
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';
  static String _two(int n) => n.toString().padLeft(2, '0');
}
