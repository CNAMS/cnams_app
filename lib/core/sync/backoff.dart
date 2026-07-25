// Exponential backoff for failed sync attempts. Pure Dart.
//
// After a transient failure (5xx / timeout) the next attempt is delayed
// 30s, 60s, 120s, … doubling each time, capped at 1 hour, per the sync design
// in docs/PRODUCTION_ROADMAP.md §4.

import 'dart:math' as math;

const Duration syncBackoffBase = Duration(seconds: 30);
const Duration syncBackoffCap = Duration(hours: 1);

/// Delay before the next attempt for a record that has already failed
/// [attempts] times (attempts >= 1). Doubles each time, capped.
Duration backoffFor(int attempts) {
  if (attempts <= 0) return Duration.zero;
  // 2^(attempts-1) * base, guarding against overflow before the cap.
  final exp = math.min(attempts - 1, 20);
  final millis = syncBackoffBase.inMilliseconds * (1 << exp);
  final capped = math.min(millis, syncBackoffCap.inMilliseconds);
  return Duration(milliseconds: capped);
}
