import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/money.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/models.dart';

void main() {
  test('wallet amounts show two decimals with en-NG grouping', () {
    expect(naira(1250000), '₦12,500.00');
    expect(naira(1000000), '₦10,000.00');
    expect(naira(500000), '₦5,000.00');
    expect(naira(-4000000), '-₦40,000.00');
  });

  test('reward pools show no decimals', () {
    expect(rewardPool(15000000), '₦150,000');
    expect(rewardPool(50000000), '₦500,000');
    expect(rewardPool(8000000), '₦80,000');
  });

  test('demo wallet figures foot', () {
    final data = DemoData(now: DateTime(2026, 10, 3));
    final totals = walletTotals(data.ledger, data.withdrawals);
    expect(naira(totals.totalEarnedKobo), '₦62,500.00');
    expect(naira(totals.pendingWithdrawalsKobo), '₦10,000.00');
    expect(naira(totals.withdrawableKobo), '₦12,500.00');
    final paidOut = data.withdrawals
        .where((w) => w.status == WithdrawalStatus.completed)
        .fold(0, (sum, w) => sum + w.amountKobo);
    expect(
      totals.totalEarnedKobo,
      paidOut + totals.pendingWithdrawalsKobo + totals.withdrawableKobo,
    );
  });

  test('demo briefs match the design counts', () {
    final data = DemoData(now: DateTime(2026, 10, 3));
    expect(data.briefs.where((b) => b.status == BriefStatus.live).length, 11);
    expect(data.briefs.where((b) => b.status == BriefStatus.closed).length, 2);
    final sunline = data.briefs.singleWhere((b) => b.businessName == 'Sunline');
    expect(rewardPool(sunline.rewardPoolKobo), '₦150,000');
    final swapit = data.briefs.singleWhere((b) => b.businessName == 'Swapit');
    expect(swapit.deadline, isNull);
  });

  test('submission statuses use the product words', () {
    expect(SubmissionStatus.pending.label, 'Under review');
    expect(SubmissionStatus.scored.label, 'Under review');
    expect(SubmissionStatus.winner.label, 'Winner');
    expect(SubmissionStatus.filteredOut.label, 'Not selected');
    expect(DemoData.savedBank.maskedNumber, '••6789');
  });
}
