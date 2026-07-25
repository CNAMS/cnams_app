// The roles a signed-in user can hold. Identity/auth lands in EX2; the enum
// exists now so the theme (EX0) and, later, navigation and guards can be
// parameterised by role.
//
// See docs/ANKUR_EXPERIENCE_ROADMAP.md.

enum AppRole {
  aww,
  supervisor,
  doctor,
  parent,
  admin;

  /// Stable string for storage / API.
  String get id => name;

  static AppRole fromId(String id) =>
      AppRole.values.firstWhere((r) => r.name == id, orElse: () => AppRole.aww);
}
