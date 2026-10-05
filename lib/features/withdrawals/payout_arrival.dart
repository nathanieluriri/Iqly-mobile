import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../data/models.dart';
import '../../data/wallet_service.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../wallet/wallet_routes.dart';
import '../wallet/wallet_state.dart';

/// The newest withdrawal that arrived within [payoutArrivalShown], for
/// B14 · Home · after payout (194:10143). Null when there is none.
final recentPayoutProvider = Provider<Withdrawal?>((ref) {
  final data = ref.watch(walletProvider).value;
  if (data == null) return null;
  final now = ref.watch(clockProvider)();
  Withdrawal? newest;
  for (final w in data.withdrawals) {
    final arrived = w.completedAt;
    if (w.status != WithdrawalStatus.completed || arrived == null) continue;
    if (now.difference(arrived) > payoutArrivalShown) continue;
    if (newest == null || arrived.isAfter(newest.completedAt!)) newest = w;
  }
  return newest;
});

/// The arrival row under the feed chips: "₦10,000.00 completed" with the
/// bank, opening the withdrawal. It is the first thing to arrive (fade and
/// rise 12) the first time Home shows it; no haptic (spec 7.9).
class PayoutArrivalRow extends StatelessWidget {
  const PayoutArrivalRow({super.key, required this.payout});

  final Withdrawal payout;

  @override
  Widget build(BuildContext context) {
    final bank = payout.destination;
    return Arrive(
      whenSeen: true,
      child: IqListRow(
        label: '${naira(payout.amountKobo)} ${payout.statusWord}',
        description: bank ?? '',
        showDescription: bank != null,
        icon: IqIcons.bank,
        divider: false,
        onTap: () => context.push(withdrawalPath(payout.id)),
      ),
    );
  }
}
