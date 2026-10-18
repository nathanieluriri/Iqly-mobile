import 'dart:async';

import '../../core/backend.dart';
import '../../core/session.dart';
import '../api_client.dart';
import '../local/local_rows.dart';
import '../models.dart';
import '../pin_service.dart';
import '../wallet_service.dart';
import 'mappers.dart';

typedef _Attempt = ({int amountKobo, String key, String? bankAccountId});

/// Bank checks, the payout account and withdrawals on the iQLY API
/// (contract 6). Every call goes online and none is queued. Withdrawals run
/// here only while that feature is live too; paused, they refuse before
/// anything is sent. Once the API holds a withdrawal PIN (contract 13.1) a
/// withdrawal carries it in its body; the service never keeps it.
class LiveWalletService implements WalletService {
  LiveWalletService(
    this.api, {
    this.withdrawals = true,
    this.bankAccounts = false,
    this.pollEvery = const Duration(seconds: 5),
    AccountScope? scope,
  }) : scope = scope ?? AccountScope.always();

  final ApiClient api;

  /// The account's stretch this service serves: once it has closed, a
  /// saved account's answer fails with [AccountChanged] and a watched
  /// withdrawal is asked after no more.
  final AccountScope scope;

  /// Whether withdrawals run on the API.
  final bool withdrawals;

  /// Whether the API keeps several accounts (contract 10.2) rather than one.
  final bool bankAccounts;

  /// How often a withdrawal on hold is asked after while it is watched.
  final Duration pollEvery;

  /// The withdrawal whose answer never came: the API may hold it, so the
  /// next request sends it again, with its own key and amount, before
  /// anything new goes.
  _Attempt? _unsettled;

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

  /// With several accounts the new one joins them, the default only when
  /// it is the first; with one, saving replaces it. Throws
  /// [ApiUnreachable] offline and [ApiRefused] when the API says no
  /// (BANK_ACCOUNT_LIMIT at the sixth).
  @override
  Future<SavedBank> addAccount(SavedBank account) async {
    final body = {
      'bankCode': account.bankCode,
      'accountNumber': account.accountNumber,
    };
    final res = await scope.guard(
      bankAccounts
          ? api.post('/wallet/bank-accounts', body)
          : api.put('/wallet/bank-account', body),
    );
    if (!res.ok) throw ApiRefused(res.status, res.code);
    final saved = savedBankFromJson(res.body['data']);
    if (saved == null) throw ApiRefused(res.status);
    return saved;
  }

  /// With one account it is always the default.
  @override
  Future<void> setDefault(SavedBank account) async {
    final id = account.id;
    if (!bankAccounts || id == null) return;
    final res = await scope.guard(
      api.post('/wallet/bank-accounts/${Uri.encodeComponent(id)}/default'),
    );
    if (!res.ok) throw ApiRefused(res.status, res.code);
  }

  /// The accounts left. BANK_ACCOUNT_IN_USE while a withdrawal to it is on
  /// its way.
  @override
  Future<List<SavedBank>> removeAccount(SavedBank account) async {
    final id = account.id;
    if (!bankAccounts || id == null) {
      throw const FeaturePaused(LiveFeature.bankAccounts);
    }
    final res = await scope.guard(
      api.send('DELETE', '/wallet/bank-accounts/${Uri.encodeComponent(id)}'),
    );
    if (!res.ok) throw ApiRefused(res.status, res.code);
    return savedBanksFromJson(res.body['data']);
  }

  /// With several saved accounts [account] goes by its id; with one the
  /// API pays it, so only the amount goes. An unsettled
  /// request goes again first, whatever is asked now: the withdrawal it
  /// made is the answer, and only a definite refusal lets the new one go,
  /// under a new key. No date of birth, under 18 and a closing account keep
  /// their reason; any other refusal reads as unknown, which the sheet
  /// words as "Couldn't send. Nothing was sent."
  @override
  Future<WithdrawResult> withdraw({
    required int amountKobo,
    required SavedBank account,
    String? pin,
  }) async {
    if (!withdrawals) {
      return const WithdrawResult.failure(WalletFailure.unknown);
    }
    final held = _unsettled;
    if (held != null) {
      final again = await _request(held, resent: true, pin: pin);
      if (again.unsettled) return again;
      // A PIN refusal says nothing of whether the first send was stored:
      // it stays held, so the send with the PIN goes under its key.
      if (again.failure == WalletFailure.pin) {
        return WithdrawResult.failure(
          WalletFailure.pin,
          pin: again.pin,
          unsettled: true,
        );
      }
      _unsettled = null;
      if (again.failure == WalletFailure.accountGone) return again;
      if (again.withdrawal case final landed?) {
        return WithdrawResult.requested(landed, earlier: true);
      }
    }
    final attempt = (
      amountKobo: amountKobo,
      key: LocalRows.newId(),
      bankAccountId: bankAccounts ? account.id : null,
    );
    _unsettled = attempt;
    final result = await _request(attempt, resent: false, pin: pin);
    if (!result.unsettled) _unsettled = null;
    return result;
  }

  Future<WithdrawResult> _request(
    _Attempt attempt, {
    required bool resent,
    String? pin,
  }) async {
    final ApiResponse res;
    try {
      res = await api.send(
        'POST',
        '/wallet/withdrawals',
        body: {
          'amount': attempt.amountKobo,
          'bankAccountId': ?attempt.bankAccountId,
          'pin': ?pin,
        },
        idempotencyKey: attempt.key,
      );
    } on ApiUnreachable catch (error) {
      // A send again that never left says nothing of the first one.
      return WithdrawResult.failure(
        WalletFailure.offline,
        unsettled: resent || !error.nothingSent,
      );
    }
    final withdrawal = res.ok ? withdrawalFromJson(res.body['data']) : null;
    if (withdrawal != null) return WithdrawResult.requested(withdrawal);
    if (res.ok || _mayHaveLanded(res.status)) {
      return const WithdrawResult.failure(
        WalletFailure.unknown,
        unsettled: true,
      );
    }
    final pinRefused = PinRefused.of(res);
    if (pinRefused.problem
        case PinProblem.required ||
            PinProblem.incorrect ||
            PinProblem.locked ||
            PinProblem.resetRequired) {
      return WithdrawResult.failure(WalletFailure.pin, pin: pinRefused);
    }
    return WithdrawResult.failure(switch (res.code) {
      'WITHDRAWAL_BELOW_MINIMUM' => WalletFailure.belowMinimum,
      'WITHDRAWAL_ABOVE_MAXIMUM' => WalletFailure.aboveMaximum,
      'PROFILE_INCOMPLETE' => WalletFailure.profileIncomplete,
      'UNDER_AGE' => WalletFailure.underAge,
      'ACCOUNT_CLOSING' => WalletFailure.closing,
      'BANK_ACCOUNT_NOT_FOUND' => WalletFailure.accountGone,
      _ => WalletFailure.unknown,
    });
  }

  /// A timeout, a throttle or a server fault says nothing of whether the
  /// request was stored.
  static bool _mayHaveLanded(int status) =>
      status == 408 || status == 429 || status >= 500;

  /// [withdrawal] at once, then asks the API every [pollEvery] while it is
  /// pending or processing and passes on each change. Ends on a final
  /// status, when the listener goes, or once [scope] has closed.
  @override
  Stream<Withdrawal> watch(Withdrawal withdrawal) {
    if (!withdrawals) return Stream.value(withdrawal);
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
      if (!scope.open) return finish();
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

  /// Unanswered or refused, it fails; a paused feature refuses before
  /// asking.
  @override
  Future<Withdrawal?> withdrawal(String id) async {
    if (!withdrawals) throw const FeaturePaused(LiveFeature.withdrawals);
    final res = await api.get('/wallet/withdrawals/${Uri.encodeComponent(id)}');
    if (res.status == 404) return null;
    if (!res.ok) throw ApiRefused.of(res);
    return withdrawalFromJson(res.body['data']);
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

  /// A live launch checks the PIN on the API ([PinService.verify]).
  @override
  Future<bool> confirmPin(String pin) async => false;
}
