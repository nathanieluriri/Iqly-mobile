/// Relative times as the product writes them: "1 day ago", "In 20 days",
/// and the short mono form "1d ago" for list rows. Whole days and hours are
/// rounded so a timestamp taken a moment earlier still reads as the same day.
String timeAgo(DateTime at, DateTime now) {
  final (amount, unit) = _span(now.difference(at));
  if (amount == 0) return 'Just now';
  return '$amount ${_plural(unit, amount)} ago';
}

String timeAgoShort(DateTime at, DateTime now) {
  final (amount, unit) = _span(now.difference(at));
  if (amount == 0) return 'Just now';
  return '$amount${unit == _Unit.day ? 'd' : 'h'} ago';
}

/// When a brief closes: "In 20 days", "In 6h", "Closed" or "No deadline".
String closesIn(DateTime? deadline, DateTime now) {
  if (deadline == null) return 'No deadline';
  if (!deadline.isAfter(now)) return 'Closed';
  final (amount, unit) = _span(deadline.difference(now));
  if (unit == _Unit.hour) return 'In ${amount < 1 ? 1 : amount}h';
  return 'In $amount ${_plural(unit, amount)}';
}

enum _Unit { hour, day }

(int, _Unit) _span(Duration d) {
  final minutes = d.inMinutes.abs();
  final days = (minutes / Duration.minutesPerDay).round();
  if (days >= 1) return (days, _Unit.day);
  return ((minutes / Duration.minutesPerHour).round(), _Unit.hour);
}

String _plural(_Unit unit, int amount) {
  final word = unit == _Unit.day ? 'day' : 'hour';
  return amount == 1 ? word : '${word}s';
}
