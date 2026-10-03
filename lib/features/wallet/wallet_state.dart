import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

/// One Activity row: an award from the ledger or a withdrawal.
class ActivityItem {
  const ActivityItem.award(LedgerEntry this.award) : withdrawal = null;
  const ActivityItem.withdrawal(Withdrawal this.withdrawal) : award = null;

  final LedgerEntry? award;
  final Withdrawal? withdrawal;

  DateTime get at => award?.createdAt ?? withdrawal!.createdAt;
}

/// The wallet as the web computes it: every figure from the ledger and the
/// withdrawal rows through [walletTotals], so earned always equals paid out
/// plus on hold plus available.
class WalletData {
  const WalletData({
    required this.ledger,
    required this.withdrawals,
    required this.savedBank,
    required this.banks,
  });

  final List<LedgerEntry> ledger;
  final List<Withdrawal> withdrawals;
  final SavedBank? savedBank;
  final List<Bank> banks;

  WalletTotals get totals => walletTotals(ledger, withdrawals);

  int get onHoldCount => withdrawals.where((w) => w.onHold).length;

  /// Awards and withdrawals, newest first. Completed withdrawals also sit
  /// in the ledger as debits; the withdrawal row stands for them.
  List<ActivityItem> get activity => [
    for (final l in ledger)
      if (l.type == LedgerType.award) ActivityItem.award(l),
    for (final w in withdrawals) ActivityItem.withdrawal(w),
  ]..sort((a, b) => b.at.compareTo(a.at));

  /// "Access Bank ••6789", or blank with no bank saved.
  String get bankLine {
    final bank = savedBank;
    return bank == null ? ' ' : '${bank.bankName} ${bank.maskedNumber}';
  }

  Withdrawal? withdrawal(String id) =>
      withdrawals.where((w) => w.id == id).firstOrNull;

  WalletData copyWith({
    List<LedgerEntry>? ledger,
    List<Withdrawal>? withdrawals,
  }) => WalletData(
    ledger: ledger ?? this.ledger,
    withdrawals: withdrawals ?? this.withdrawals,
    savedBank: savedBank,
    banks: banks,
  );
}

class WalletNotifier extends AsyncNotifier<WalletData> {
  @override
  Future<WalletData> build() async {
    final repo = ref.watch(repositoryProvider);
    final (ledger, withdrawals, savedBank, banks) = await (
      repo.ledger(),
      repo.withdrawals(),
      repo.savedBank(),
      repo.banks(),
    ).wait;
    return WalletData(
      ledger: ledger,
      withdrawals: withdrawals,
      savedBank: savedBank,
      banks: banks,
    );
  }

  void retry() => ref.invalidateSelf();

  /// A withdrawal the API just accepted: it goes on hold.
  void add(Withdrawal withdrawal) => _edit(
    (data) => data.copyWith(withdrawals: [withdrawal, ...data.withdrawals]),
  );

  /// A newer copy of a withdrawal. Arriving moves it from on hold to a
  /// ledger debit; failing releases the hold.
  void replace(Withdrawal withdrawal) => _edit((data) {
    final before = data.withdrawal(withdrawal.id);
    if (before == null) return data;
    final arrived =
        withdrawal.status == WithdrawalStatus.completed &&
        before.status != WithdrawalStatus.completed;
    return data.copyWith(
      withdrawals: [
        for (final w in data.withdrawals)
          w.id == withdrawal.id ? withdrawal : w,
      ],
      ledger: arrived
          ? [
              LedgerEntry(
                id: 'debit-${withdrawal.id}',
                type: LedgerType.withdrawal,
                amountKobo: -withdrawal.amountKobo,
                createdAt: withdrawal.completedAt ?? ref.read(clockProvider)(),
              ),
              ...data.ledger,
            ]
          : null,
    );
  });

  void _edit(WalletData Function(WalletData data) change) {
    final data = state.value;
    if (data == null) return;
    state = AsyncData(change(data));
  }

  /// An award the API put on the ledger (support credited an activation
  /// reward). It lands once, however often it is reported.
  void credit(LedgerEntry award) => _edit(
    (data) => data.ledger.any((l) => l.id == award.id)
        ? data
        : data.copyWith(ledger: [award, ...data.ledger]),
  );
}

/// No automatic retry: the failed state offers "Try again".
final walletProvider = AsyncNotifierProvider<WalletNotifier, WalletData>(
  WalletNotifier.new,
  retry: (_, _) => null,
);
