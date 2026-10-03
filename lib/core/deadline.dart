import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/urgency.dart';

/// The wall clock, overridable so goldens and tests read a fixed time.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Time left to the minute, so a brief created "1 day" out still reads as a
/// day a few seconds later. Null when the brief has no deadline.
Duration? timeLeft(DateTime? deadline, DateTime now) {
  if (deadline == null) return null;
  return Duration(minutes: (deadline.difference(now).inSeconds / 60).round());
}

/// The Exp/Urgency wording: "Closes in 6h", "Closes in 1 day",
/// "Closes in 25 days", "No deadline", "Closed".
String closesIn(Duration? left, {bool closed = false}) {
  if (closed || (left != null && left <= Duration.zero)) return 'Closed';
  if (left == null) return 'No deadline';
  final hours = (left.inMinutes / 60).round();
  if (hours < 24) return 'Closes in ${hours < 1 ? 1 : hours}h';
  final days = (hours / 24).round();
  return 'Closes in $days ${days == 1 ? 'day' : 'days'}';
}

/// Hot under 24 h, Warm under 7 days, Calm otherwise, Closed once closed.
/// Reads the same rounded hours as [closesIn], so "Closes in 1 day" is Warm.
IqUrgencyTone urgencyTone(Duration? left, {bool closed = false}) {
  final hours = left == null ? 0 : (left.inMinutes / 60).round();
  final rounded = hours >= 1 ? Duration(hours: hours) : left;
  return IqUrgencyTone.of(rounded, closed: closed);
}

/// Brief detail's SUBMISSIONS CLOSE value: "In 6 hours", "In 1 day".
String closesInWords(Duration? left, {bool closed = false}) {
  if (closed || (left != null && left <= Duration.zero)) return 'Closed';
  if (left == null) return 'No deadline';
  final hours = (left.inMinutes / 60).round();
  if (hours < 24) {
    final h = hours < 1 ? 1 : hours;
    return 'In $h ${h == 1 ? 'hour' : 'hours'}';
  }
  final days = (hours / 24).round();
  return 'In $days ${days == 1 ? 'day' : 'days'}';
}
