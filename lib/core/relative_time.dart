/// Relative times as the product writes them: "1 day ago" and the short
/// mono form "1d ago" for list rows. Whole days and hours are rounded so a
/// timestamp taken a moment earlier still reads as the same day. Deadlines
/// ("In 20 days", "Closes in 6h") live in deadline.dart.
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
