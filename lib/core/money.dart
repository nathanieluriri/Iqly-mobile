import 'package:intl/intl.dart';

final _whole = NumberFormat('#,##0', 'en');
final _twoDecimals = NumberFormat('#,##0.00', 'en');

/// Amounts are stored in kobo. Wallet figures show two decimals (₦10,000.00),
/// reward pools show none (₦150,000).
String naira(int kobo, {bool decimals = true}) {
  final sign = kobo < 0 ? '-' : '';
  final value = kobo.abs() / 100;
  final digits = decimals ? _twoDecimals.format(value) : _whole.format(value);
  return '$sign₦$digits';
}

String rewardPool(int kobo) => naira(kobo, decimals: false);

/// A pool on a card's reward chip: whole thousands as "₦150k", whole
/// millions as "₦1m", smaller amounts in full ("₦500"). Never decimals.
String rewardShort(int kobo) {
  final naira = kobo ~/ 100;
  if (naira >= 1000000 && naira % 1000000 == 0) return '₦${naira ~/ 1000000}m';
  if (naira >= 1000 && naira % 1000 == 0) return '₦${naira ~/ 1000}k';
  return rewardPool(kobo);
}
