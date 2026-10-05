import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/share_service.dart';
import 'package:iqly_mobile/data/wallet_service.dart';

import 'app_harness.dart';

/// The wallet service answering at once. [payoutStep] null keeps every
/// withdrawal where it is.
DemoWalletService instantWallet({Duration? payoutStep}) => DemoWalletService(
  delay: Duration.zero,
  payoutStep: payoutStep,
  clock: () => figmaNow,
);

List<Override> walletOverrides({
  DemoWalletService? wallet,
  DemoShareService? share,
}) => [
  walletServiceProvider.overrideWithValue(wallet ?? instantWallet()),
  shareServiceProvider.overrideWithValue(share ?? DemoShareService()),
];

/// The demo wallet at the Figma 9:41.
class WalletRepository extends DemoRepository {
  WalletRepository() : super(DemoData(now: figmaNow));
}

/// The ledger call fails until [fail] is cleared.
class FailingWalletRepository extends WalletRepository {
  int calls = 0;
  bool fail = true;

  @override
  Future<List<LedgerEntry>> ledger() async {
    calls++;
    if (fail) throw Exception('offline');
    return super.ledger();
  }
}

/// Nothing on the ledger and no withdrawals yet.
class EmptyWalletRepository extends WalletRepository {
  @override
  Future<List<LedgerEntry>> ledger() async => const [];

  @override
  Future<List<Withdrawal>> withdrawals() async => const [];
}

/// The ledger never answers.
class PendingWalletRepository extends WalletRepository {
  final _never = Completer<List<LedgerEntry>>();

  @override
  Future<List<LedgerEntry>> ledger() => _never.future;
}

/// After the B5 withdraw: ₦5,000.00 to Access Bank ••6789 just requested.
class RequestedWalletRepository extends WalletRepository {
  static final requested = Withdrawal(
    id: 'w4',
    amountKobo: 500000,
    status: WithdrawalStatus.pending,
    createdAt: figmaNow,
    reference: 'IQ-WD-261003-K7QX',
    bankName: DemoData.savedBank.bankName,
    accountNumber: DemoData.savedBank.accountNumber,
  );

  @override
  Future<List<Withdrawal>> withdrawals() async => [
    requested,
    ...await super.withdrawals(),
  ];
}

/// The pending ₦10,000.00 arrived five minutes ago: B14 Home after payout.
class PaidOutWalletRepository extends WalletRepository {
  static final arrivedAt = figmaNow.subtract(const Duration(minutes: 5));

  @override
  Future<List<Withdrawal>> withdrawals() async => [
    for (final w in await super.withdrawals())
      w.id == 'w3'
          ? w.copyWith(
              status: WithdrawalStatus.completed,
              approvedAt: figmaNow.subtract(const Duration(hours: 1)),
              sentAt: figmaNow.subtract(const Duration(minutes: 40)),
              completedAt: arrivedAt,
            )
          : w,
  ];

  @override
  Future<List<LedgerEntry>> ledger() async => [
    LedgerEntry(
      id: 'debit-w3',
      type: LedgerType.withdrawal,
      amountKobo: -1000000,
      createdAt: arrivedAt,
    ),
    ...await super.ledger(),
  ];
}

/// B14 · Withdrawal · arrived (485:39669): the pending ₦10,000.00 arrived
/// today at 3:06 pm.
class ArrivedWalletRepository extends WalletRepository {
  static final arrivedAt = DateTime(2026, 10, 3, 15, 6);

  @override
  Future<List<Withdrawal>> withdrawals() async => [
    for (final w in await super.withdrawals())
      w.id == 'w3'
          ? w.copyWith(
              status: WithdrawalStatus.completed,
              sentAt: DateTime(2026, 10, 3, 15, 3),
              completedAt: arrivedAt,
            )
          : w,
  ];
}

/// A wallet service whose withdrawal never answers: the Sending state.
class HangingWalletService extends DemoWalletService {
  HangingWalletService()
    : super(delay: Duration.zero, payoutStep: null, clock: () => figmaNow);

  @override
  Future<WithdrawResult> withdraw({
    required int amountKobo,
    required SavedBank account,
  }) => Completer<WithdrawResult>().future;
}
