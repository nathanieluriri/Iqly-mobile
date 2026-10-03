import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/ui/urgency.dart';

void main() {
  final now = DateTime(2026, 10, 3, 9, 41);
  Duration? left(Duration? d) => d == null ? null : timeLeft(now.add(d), now);

  test('the urgency chip words and tones', () {
    expect(closesIn(left(const Duration(hours: 6))), 'Closes in 6h');
    expect(urgencyTone(left(const Duration(hours: 6))), IqUrgencyTone.hot);
    final day = left(const Duration(days: 1, seconds: -5));
    expect(closesIn(day), 'Closes in 1 day');
    expect(urgencyTone(day), IqUrgencyTone.warm);
    expect(closesIn(left(const Duration(days: 25))), 'Closes in 25 days');
    expect(urgencyTone(left(const Duration(days: 25))), IqUrgencyTone.calm);
    expect(closesIn(null), 'No deadline');
    expect(urgencyTone(null), IqUrgencyTone.calm);
    expect(closesIn(left(const Duration(days: -3))), 'Closed');
    expect(urgencyTone(left(const Duration(days: -3))), IqUrgencyTone.closed);
  });

  test('the fact row words', () {
    final soon = left(const Duration(days: 20, seconds: -5));
    expect(closesInWords(soon), 'In 20 days');
    expect(closesInWords(left(const Duration(days: 1))), 'In 1 day');
    expect(closesInWords(left(const Duration(hours: 6))), 'In 6 hours');
    expect(closesInWords(left(const Duration(hours: 1))), 'In 1 hour');
    expect(closesInWords(left(const Duration(days: -3))), 'Closed');
    expect(
      closesInWords(left(const Duration(days: 9)), closed: true),
      'Closed',
    );
    expect(closesInWords(null), 'No deadline');
  });
}
