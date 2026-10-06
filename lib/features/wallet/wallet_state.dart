import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../ui/wallet_card.dart';

/// One Activity row: an award from the ledger or a withdrawal.
class ActivityItem {
  const ActivityItem.award(LedgerEntry this.award) : withdrawal = null;
  const ActivityItem.withdrawal(Withdrawal this.withdrawal) : award = null;

  final LedgerEntry? award;
  final Withdrawal? withdrawal;

  DateTime get at => award?.createdAt ?? withdrawal!.createdAt;

  String get key => award?.id ?? withdrawal!.id;
}

/// The wallet as the web computes it: every figure from the ledger and the
/// withdrawal rows through [walletTotals], so earned always equals paid out
/// plus on its way plus available.
class WalletData {
  const WalletData({
    required this.ledger,
    required this.withdrawals,
    required this.accounts,
    required this.banks,
  });

  final List<LedgerEntry> ledger;
  final List<Withdrawal> withdrawals;

  /// Saved payout accounts, the default first.
  final List<SavedBank> accounts;
  final List<Bank> banks;

  SavedBank? get savedBank => accounts.firstOrNull;

  WalletTotals get totals => walletTotals(ledger, withdrawals);

  int get onHoldCount => withdrawals.where((w) => w.onHold).length;

  /// Rewards paid for winning submissions.
  int get winningSubmissions => ledger
      .where(
        (l) =>
            l.type == LedgerType.award && l.source == RewardSource.submission,
      )
      .length;

  /// Awards and withdrawals, newest first. Completed withdrawals also sit
  /// in the ledger as debits; the withdrawal row stands for them.
  List<ActivityItem> get activity => [
    for (final l in ledger)
      if (l.type == LedgerType.award) ActivityItem.award(l),
    for (final w in withdrawals) ActivityItem.withdrawal(w),
  ]..sort((a, b) => b.at.compareTo(a.at));

  Withdrawal? withdrawal(String id) =>
      withdrawals.where((w) => w.id == id).firstOrNull;

  WalletData copyWith({
    List<LedgerEntry>? ledger,
    List<Withdrawal>? withdrawals,
    List<SavedBank>? accounts,
  }) => WalletData(
    ledger: ledger ?? this.ledger,
    withdrawals: withdrawals ?? this.withdrawals,
    accounts: accounts ?? this.accounts,
    banks: banks,
  );
}

class WalletNotifier extends AsyncNotifier<WalletData> {
  @override
  Future<WalletData> build() => _load();

  Future<WalletData> _load() async {
    final repo = ref.watch(repositoryProvider);
    final (ledger, withdrawals, accounts, banks) = await (
      repo.ledger(),
      repo.withdrawals(),
      repo.savedBanks(),
      repo.banks(),
    ).wait;
    return WalletData(
      ledger: ledger,
      withdrawals: withdrawals,
      accounts: accounts,
      banks: banks,
    );
  }

  void retry() => ref.invalidateSelf();

  static List<T> _merge<T>(List<T> held, List<T> fresh, String Function(T) id) {
    final known = {for (final x in held) id(x)};
    return [
      ...held,
      for (final x in fresh)
        if (!known.contains(id(x))) x,
    ];
  }

  /// Reloads behind the shown figures (designer answer 30): no skeleton,
  /// and a failure keeps what is on screen.
  Future<void> refreshQuietly() async {
    if (!state.hasValue) return;
    final WalletData fresh;
    try {
      fresh = await _load();
    } on Object {
      return;
    }
    final held = state.value;
    if (!ref.mounted || held == null) return;
    // Rows and accounts this session already holds win: a reload that lags
    // behind a withdrawal just made must not take it away.
    state = AsyncData(
      fresh.copyWith(
        ledger: _merge(held.ledger, fresh.ledger, (l) => l.id),
        withdrawals: _merge(held.withdrawals, fresh.withdrawals, (w) => w.id),
        accounts: _merge(held.accounts, fresh.accounts, (a) => a.accountNumber),
      ),
    );
  }

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

  /// An award the API put on the ledger (an activation reward). It lands
  /// once, however often it is reported.
  void credit(LedgerEntry award) => _edit(
    (data) => data.ledger.any((l) => l.id == award.id)
        ? data
        : data.copyWith(ledger: [award, ...data.ledger]),
  );

  /// A newly saved account, after the default.
  void addAccount(SavedBank account) => _edit(
    (data) => data.copyWith(
      accounts: [
        for (final a in data.accounts)
          if (a.accountNumber != account.accountNumber) a,
        account,
      ],
    ),
  );

  /// [account] becomes the default and moves first.
  void setDefault(SavedBank account) => _edit(
    (data) => data.copyWith(
      accounts: [
        account,
        for (final a in data.accounts)
          if (a.accountNumber != account.accountNumber) a,
      ],
    ),
  );

  void _edit(WalletData Function(WalletData data) change) {
    final data = state.value;
    if (data == null) return;
    state = AsyncData(change(data));
  }
}

/// No automatic retry: the failed state offers "Try again".
final walletProvider = AsyncNotifierProvider<WalletNotifier, WalletData>(
  WalletNotifier.new,
  retry: (_, _) => null,
);

/// The brief each winning submission answered, by submission id, to name
/// the business and the brief on reward rows. Only the wallet pages read
/// it, so Home's payout row does not load submissions.
final rewardBriefsProvider = FutureProvider<Map<String, Brief>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final (submissions, briefs) = await (repo.submissions(), repo.briefs()).wait;
  final byId = {for (final b in briefs) b.id: b};
  return {for (final s in submissions) s.id: ?byId[s.briefId]};
});

/// The Wallet tab's lens: which balance the card shows and whether the
/// figures are hidden. Hiding holds across the wallet pages.
class WalletLens {
  const WalletLens({
    this.balance = IqWalletCardBalance.available,
    this.hidden = false,
  });

  final IqWalletCardBalance balance;
  final bool hidden;
}

class WalletLensNotifier extends Notifier<WalletLens> {
  @override
  WalletLens build() => const WalletLens();

  void show(IqWalletCardBalance balance) =>
      state = WalletLens(balance: balance, hidden: state.hidden);

  void toggleHidden() =>
      state = WalletLens(balance: state.balance, hidden: !state.hidden);
}

final walletLensProvider = NotifierProvider<WalletLensNotifier, WalletLens>(
  WalletLensNotifier.new,
);
