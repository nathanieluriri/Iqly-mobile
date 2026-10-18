import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/wallet_service.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../wallet/wallet_routes.dart';
import '../wallet/wallet_state.dart';

/// The payouts Home no longer shows (owner, 18 Oct: once seen it is a
/// distraction). One seen on Home stays for the rest of that open, so it
/// never vanishes under the finger, and is gone from the next launch; one
/// opened is gone at once.
class SeenPayouts extends Notifier<Set<String>> {
  static const key = 'home.seenPayouts';
  static const kept = 20;

  @override
  Set<String> build() => {
    ...?ref.read(sharedPreferencesProvider).getStringList(key),
  };

  void seen(String id) => _keep(id);

  void opened(String id) {
    _keep(id);
    if (!state.contains(id)) state = {...state, id};
  }

  void _keep(String id) {
    final prefs = ref.read(sharedPreferencesProvider);
    final ids = [...?prefs.getStringList(key)];
    if (ids.contains(id)) return;
    ids.add(id);
    if (ids.length > kept) ids.removeRange(0, ids.length - kept);
    prefs.setStringList(key, ids);
  }
}

final seenPayoutsProvider = NotifierProvider<SeenPayouts, Set<String>>(
  SeenPayouts.new,
);

/// The newest withdrawal that arrived within [payoutArrivalShown] and is
/// not yet seen, for B14 · Home · after payout (194:10143). Null when there
/// is none.
final recentPayoutProvider = Provider<Withdrawal?>((ref) {
  final data = ref.watch(walletProvider).value;
  if (data == null) return null;
  final now = ref.watch(clockProvider)();
  final seen = ref.watch(seenPayoutsProvider);
  Withdrawal? newest;
  for (final w in data.withdrawals) {
    final arrived = w.completedAt;
    if (w.status != WithdrawalStatus.completed || arrived == null) continue;
    if (seen.contains(w.id)) continue;
    if (now.difference(arrived) > payoutArrivalShown) continue;
    if (newest == null || arrived.isAfter(newest.completedAt!)) newest = w;
  }
  return newest;
});

/// The arrival row under the feed chips: "₦10,000.00 completed" with the
/// bank, opening the withdrawal. It is the first thing to arrive (fade and
/// rise 12) the first time Home shows it; no haptic (spec 7.9).
class PayoutArrivalRow extends ConsumerWidget {
  const PayoutArrivalRow({super.key, required this.payout});

  final Withdrawal payout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.read(seenPayoutsProvider.notifier)..seen(payout.id);
    final bank = payout.destination;
    return Arrive(
      whenSeen: true,
      child: IqListRow(
        label: '${naira(payout.amountKobo)} ${payout.statusWord}',
        description: bank ?? '',
        showDescription: bank != null,
        icon: IqIcons.bank,
        divider: false,
        onTap: () {
          context.open(withdrawalPath(payout.id));
          seen.opened(payout.id);
        },
      ),
    );
  }
}
