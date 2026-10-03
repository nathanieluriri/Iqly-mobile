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
