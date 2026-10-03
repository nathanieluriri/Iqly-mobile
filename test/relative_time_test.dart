import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/relative_time.dart';

void main() {
  final now = DateTime(2026, 10, 3, 12);

  test('sent times round to whole days or hours', () {
    final yesterday = now.subtract(const Duration(days: 1, seconds: -5));
    expect(timeAgo(yesterday, now), '1 day ago');
    expect(timeAgoShort(yesterday, now), '1d ago');
    expect(timeAgo(now.subtract(const Duration(days: 30)), now), '30 days ago');
    expect(timeAgoShort(now.subtract(const Duration(hours: 2)), now), '2h ago');
  });
}
