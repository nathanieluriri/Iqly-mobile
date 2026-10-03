import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';

/// The web form's floor: ₦1,000.
const minimumWithdrawalKobo = 100000;

/// The Amount help line, as the web form writes it.
String amountHelp(int availableKobo) =>
    'Minimum ₦1,000 · available ${naira(availableKobo)}';

/// The web rule: at least ₦1,000 and no more than is available.
bool validWithdrawal(int? kobo, int availableKobo) =>
    kobo != null && kobo >= minimumWithdrawalKobo && kobo <= availableKobo;

/// Kobo from what the Amount field holds ("₦5,000.50", "5000"); null when
/// it is empty or not an amount.
int? parseNaira(String text) {
  final clean = text.replaceAll(RegExp(r'[₦,\s]'), '');
  if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(clean)) return null;
  final parts = clean.split('.');
  final kobo = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
  return int.parse(parts[0]) * 100 + int.parse(kobo);
}

/// The figure split the way Exp/BalanceHero sets it: "₦12,500" and ".00".
(String, String) nairaParts(int kobo) {
  final whole = naira(kobo - kobo % 100, decimals: false);
  return (whole, '.${(kobo % 100).toString().padLeft(2, '0')}');
}

/// "Today, 7:40 am", "11 days ago, 2:05 pm": the B14 receipt and step
/// times, counted in calendar days.
String withdrawalTime(DateTime at, DateTime now) {
  final days =
      (DateTime(
                now.year,
                now.month,
                now.day,
              ).difference(DateTime(at.year, at.month, at.day)).inHours /
              24)
          .round();
  final day = days <= 0 ? 'Today' : '$days ${days == 1 ? 'day' : 'days'} ago';
  return '$day, ${DateFormat('h:mm a').format(at).toLowerCase()}';
}

/// "pending" to "Pending" for the receipt tag.
String capitalized(String word) =>
    word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);

/// Formats naira as it is typed: digits grouped behind ₦, at most two
/// decimals, the caret kept at the end.
class NairaInputFormatter extends TextInputFormatter {
  const NairaInputFormatter();

  static final _grouped = NumberFormat('#,##0', 'en');
  static const _maxWholeDigits = 9;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');
    if (raw.isEmpty) return TextEditingValue.empty;
    final dot = raw.indexOf('.');
    var whole = dot < 0 ? raw : raw.substring(0, dot);
    String? fraction;
    if (dot >= 0) {
      fraction = raw.substring(dot + 1).replaceAll('.', '');
      if (fraction.length > 2) fraction = fraction.substring(0, 2);
    }
    whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (whole.length > _maxWholeDigits) return oldValue;
    final grouped = whole.isEmpty ? '0' : _grouped.format(int.parse(whole));
    final text = '₦$grouped${fraction == null ? '' : '.$fraction'}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
