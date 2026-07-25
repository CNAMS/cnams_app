// Role-aware navigation shell (EX4): one app, a different set of tabs per role.
// The destinations (and therefore which screens a role can even reach) are
// derived from the signed-in role — a role can't navigate to another role's
// surface because those destinations aren't built for it.
//
// See docs/ANKUR_EXPERIENCE_ROADMAP.md — EX4.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/features/dashboard/admin_dashboard.dart';
import 'package:cgms_app/features/dashboard/doctor_dashboard.dart';
import 'package:cgms_app/features/dashboard/parent_dashboard.dart';
import 'package:cgms_app/features/dashboard/supervisor_dashboard.dart';
import 'package:cgms_app/features/home/home_screen.dart';
import 'package:cgms_app/features/measure/result_demo_screen.dart';
import 'package:cgms_app/features/roster/roster_screen.dart';
import 'package:cgms_app/features/settings/settings_screen.dart';

typedef _Dest = ({
  Widget page,
  IconData icon,
  IconData selectedIcon,
  String label,
});

class RoleShell extends ConsumerStatefulWidget {
  const RoleShell({super.key});

  @override
  ConsumerState<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends ConsumerState<RoleShell> {
  int _index = 0;

  List<_Dest> _destsFor(AppRole role, AppLocalizations l10n) {
    final settings = (
      page: const SettingsScreen(),
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: l10n.navSettings,
    );

    switch (role) {
      case AppRole.aww:
        return [
          (
            page: const HomeScreen(),
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: l10n.navHome,
          ),
          (
            page: const RosterScreen(),
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
            label: l10n.navRoster,
          ),
          (
            page: const ResultDemoScreen(),
            icon: Icons.assignment_outlined,
            selectedIcon: Icons.assignment,
            label: l10n.navResultDemo,
          ),
          settings,
        ];
      case AppRole.supervisor:
        return [
          (
            page: const SupervisorDashboard(),
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            label: l10n.navOverview,
          ),
          (
            page: const RosterScreen(),
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
            label: l10n.navRoster,
          ),
          settings,
        ];
      case AppRole.doctor:
        return [
          (
            page: const DoctorDashboard(),
            icon: Icons.medical_services_outlined,
            selectedIcon: Icons.medical_services,
            label: l10n.navCases,
          ),
          settings,
        ];
      case AppRole.parent:
        return [
          (
            page: const ParentDashboard(),
            icon: Icons.child_care_outlined,
            selectedIcon: Icons.child_care,
            label: l10n.navChild,
          ),
          settings,
        ];
      case AppRole.admin:
        return [
          (
            page: const AdminDashboard(),
            icon: Icons.admin_panel_settings_outlined,
            selectedIcon: Icons.admin_panel_settings,
            label: l10n.navUsers,
          ),
          settings,
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(currentRoleProvider);
    final dests = _destsFor(role, l10n);
    final index = _index.clamp(0, dests.length - 1);

    return Scaffold(
      appBar: AppBar(title: Text(dests[index].label)),
      // Lazy: only the selected tab is built, so a screen's data streams open on
      // demand rather than all at once on sign-in.
      body: dests[index].page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in dests)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
