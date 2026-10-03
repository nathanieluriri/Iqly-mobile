import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/urgency.dart';

/// The deadline ladders (business rules, not motion).
abstract final class DeadlineRules {
  /// Urgency turns Hot under a day.
  static const urgencyHot = Duration(hours: 24);

  /// Urgency turns Warm under a week.
  static const urgencyWarm = Duration(days: 7);

  /// Countdown turns Hot under 6 hours.
  static const countdownHot = Duration(hours: 6);

  /// Countdown turns Warm under a day.
  static const countdownWarm = Duration(days: 1);

  /// Discover's Closing soon takes briefs closing within 3 days.
  static const closingSoon = Duration(days: 3);
}

/// The wall clock, overridable so goldens and tests read a fixed time.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Time left, rounded up to the minute so a brief due in 6 hours still reads
/// 6h a few seconds later. Null when the brief has no deadline.
Duration? timeLeft(DateTime? deadline, DateTime now) {
  if (deadline == null) return null;
  return Duration(minutes: (deadline.difference(now).inSeconds / 60).ceil());
}

/// The Exp/Urgency wording: "Closes in 6h", "Closes in 1 day",
/// "Closes in 25 days", "No deadline", "Closed". Hours and days round down
/// so the chip never promises more time than is left; the last hour counts
/// minutes.
String closesIn(Duration? left, {bool closed = false}) {
  if (closed || (left != null && left <= Duration.zero)) return 'Closed';
  if (left == null) return 'No deadline';
  if (left.inHours < 1) return 'Closes in ${left.inMinutes} min';
  if (left.inHours < 24) return 'Closes in ${left.inHours}h';
  final days = left.inDays;
  return 'Closes in $days ${days == 1 ? 'day' : 'days'}';
}

/// Hot under 24 h, Warm under 7 days, Calm otherwise, Closed once closed.
IqUrgencyTone urgencyTone(Duration? left, {bool closed = false}) =>
    IqUrgencyTone.of(left, closed: closed);

/// Brief detail's SUBMISSIONS CLOSE value: "In 6 hours", "In 1 day", rounded
/// down like [closesIn].
String closesInWords(Duration? left, {bool closed = false}) {
  if (closed || (left != null && left <= Duration.zero)) return 'Closed';
  if (left == null) return 'No deadline';
  final (n, unit) = left.inHours < 1
      ? (left.inMinutes, 'minute')
      : left.inHours < 24
      ? (left.inHours, 'hour')
      : (left.inDays, 'day');
  return 'In $n $unit${n == 1 ? '' : 's'}';
}
