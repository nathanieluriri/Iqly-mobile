import 'dart:async';

import '../api_client.dart';
import '../local/local_rows.dart';
import '../models.dart';
import '../wallet_service.dart';
import 'mappers.dart';

/// Bank checks, the payout account and withdrawals on the iQLY API
/// (contract 6). Every call goes online and none is queued. Withdrawals run
/// here only while that feature is live too; otherwise [demo] takes them,
/// as it takes the PIN, which the API does not have.
class LiveWalletService implements WalletService {
  LiveWalletService(
    this.api, {
    required this.demo,
    this.withdrawals = true,
    this.pollEvery = const Duration(seconds: 5),
  });

  final ApiClient api;
  final WalletService demo;

  /// Whether withdrawals run on the API.
  final bool withdrawals;

  /// How often a withdrawal on hold is asked after while it is watched.
  final Duration pollEvery;

  /// The withdrawal still waiting for an answer, and the key its retries
  /// carry.
  ({int amountKobo, String account, String key})? _attempt;

  @override
  Future<VerifyResult> verifyAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    final ApiResponse res;
    try {
      res = await api.post('/banks/resolve', {
        'bankCode': bankCode,
        'accountNumber': accountNumber,
      });
    } on ApiUnreachable {
      return const VerifyResult.failure(WalletFailure.offline);
    }
    final name = res.ok ? res.data['accountName'] : null;
    if (name is String && name.trim().isNotEmpty) {
      return VerifyResult.verified(name);
    }
    // 400 is the bank refusing the number (or the API refusing its shape).
    return VerifyResult.failure(
      res.ok || res.status == 400
          ? WalletFailure.unverified
          : WalletFailure.unknown,
    );
  }

  /// The API keeps one payout account: saving replaces it. Throws
  /// [ApiUnreachable] offline and [ApiRefused] when the API says no.
  @override
  Future<SavedBank> addAccount(SavedBank account) async {
    final res = await api.put('/wallet/bank-account', {
      'bankCode': account.bankCode,
      'accountNumber': account.accountNumber,
    });
    if (!res.ok) throw ApiRefused(res.status, res.code);
    final saved = savedBankFromJson(res.body['data']);
    if (saved == null) throw ApiRefused(res.status);
    return saved;
  }

  /// With one account it is always the default.
  @override
  Future<void> setDefault(SavedBank account) async {}

  /// A refusal (balance too low, profile incomplete, under 18, below the
  /// minimum, too many tries) reads as unknown, which the sheet words as
  /// "Couldn't send. Nothing was sent."
  @override
  Future<WithdrawResult> withdraw({
    required int amountKobo,
    required SavedBank account,
  }) async {
    if (!withdrawals) {
      return demo.withdraw(amountKobo: amountKobo, account: account);
    }
    final to = '${account.bankCode}:${account.accountNumber}';
    final held = _attempt;
    final key =
        held != null && held.amountKobo == amountKobo && held.account == to
        ? held.key
        : LocalRows.newId();
    _attempt = (amountKobo: amountKobo, account: to, key: key);
    final ApiResponse res;
    try {
      res = await api.send(
        'POST',
        '/wallet/withdrawals',
        body: {'amount': amountKobo},
        idempotencyKey: key,
      );
    } on ApiUnreachable {
      return const WithdrawResult.failure(WalletFailure.offline);
    }
    if (!_mayHaveLanded(res.status)) _attempt = null;
    final withdrawal = res.ok ? withdrawalFromJson(res.body['data']) : null;
    if (withdrawal != null) return WithdrawResult.requested(withdrawal);
    return const WithdrawResult.failure(WalletFailure.unknown);
  }

  /// A timeout, a throttle or a server fault says nothing of whether the
  /// request was stored, so its key stays for the retry.
  static bool _mayHaveLanded(int status) =>
      status == 408 || status == 429 || status >= 500;

  /// [withdrawal] at once, then asks the API every [pollEvery] while it is
  /// pending or processing and passes on each change. Ends on a final
  /// status, or when the listener goes.
  @override
  Stream<Withdrawal> watch(Withdrawal withdrawal) {
    if (!withdrawals) return demo.watch(withdrawal);
    late final StreamController<Withdrawal> changes;
    var current = withdrawal;
    var done = false;
    Timer? next;

    void finish() {
      done = true;
      next?.cancel();
      unawaited(changes.close());
    }

    Future<void> poll() async {
      final latest = await _fetch(current.id);
      if (done) return;
      if (latest != null && !_same(latest, current)) {
        current = latest;
        changes.add(latest);
      }
      if (current.onHold) {
        next = Timer(pollEvery, poll);
      } else {
        finish();
      }
    }

    changes = StreamController<Withdrawal>(
      onListen: () {
        changes.add(withdrawal);
        if (withdrawal.onHold) {
          unawaited(poll());
        } else {
          finish();
        }
      },
      onCancel: () {
        done = true;
        next?.cancel();
      },
    );
    return changes.stream;
  }

  Future<Withdrawal?> _fetch(String id) async {
    try {
      final res = await api.get(
        '/wallet/withdrawals/${Uri.encodeComponent(id)}',
      );
      return res.ok ? withdrawalFromJson(res.body['data']) : null;
    } on ApiUnreachable {
      return null;
    }
  }

  static bool _same(Withdrawal a, Withdrawal b) =>
      a.status == b.status &&
      a.sentAt == b.sentAt &&
      a.completedAt == b.completedAt &&
      a.failureReason == b.failureReason;

  @override
  Future<bool> confirmPin(String pin) => demo.confirmPin(pin);
}
