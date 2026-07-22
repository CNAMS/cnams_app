// Growth classification bands. Pure Dart — no Flutter import.

/// The classification presented on the Result screen.
enum GrowthClass {
  normal,
  mam, // moderate acute malnutrition
  sam, // severe acute malnutrition
  overweight,
  indeterminate, // missing/implausible inputs — never guess
}
