// Presentation helpers for a role: its localized name, brand colour and icon.
// Kept in one place so the sign-in, dashboards and nav agree.

import 'package:flutter/material.dart';

import 'package:cgms_app/core/auth/app_role.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';

String roleLabel(AppLocalizations l10n, AppRole role) => switch (role) {
      AppRole.aww => l10n.roleAww,
      AppRole.supervisor => l10n.roleSupervisor,
      AppRole.doctor => l10n.roleDoctor,
      AppRole.parent => l10n.roleParent,
      AppRole.admin => l10n.roleAdmin,
    };

Color roleColor(AppRole role) => switch (role) {
      AppRole.aww => const Color(0xFF00695C),
      AppRole.supervisor => const Color(0xFF2E7D32),
      AppRole.doctor => const Color(0xFF1565C0),
      AppRole.parent => const Color(0xFFE68A00),
      AppRole.admin => const Color(0xFF4B5570),
    };

IconData roleIcon(AppRole role) => switch (role) {
      AppRole.aww => Icons.volunteer_activism,
      AppRole.supervisor => Icons.supervisor_account,
      AppRole.doctor => Icons.medical_services,
      AppRole.parent => Icons.family_restroom,
      AppRole.admin => Icons.admin_panel_settings,
    };
