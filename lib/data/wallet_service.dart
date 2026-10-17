import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/backend.dart';
import '../core/session.dart';
import 'api_client.dart';
import 'demo_data.dart';
import 'live/live_repository.dart';
import 'live/live_wallet_service.dart';
import 'models.dart';

/// How long Home keeps showing a payout that arrived.
const payoutArrivalShown = Duration(days: 1);

/// Why a wallet call failed. The live API layer maps its codes onto these.
enum WalletFailure {
  /// The bank could not match the account number to a name.
  unverified,
  offline,
  unknown,

  /// No date of birth on the profile yet (409 PROFILE_INCOMPLETE).
  profileIncomplete,

  /// The profile's date of birth is under 18 (403 UNDER_AGE).
  underAge,

  /// The account is closing, so it takes no writes (403 ACCOUNT_CLOSING).
  closing,

  /// The saved account named is no longer saved (404
  /// BANK_ACCOUNT_NOT_FOUND).
  accountGone,
}

class VerifyResult {
  const VerifyResult.verified(String this.accountName) : failure = null;
  const VerifyResult.failure(WalletFailure this.failure) : accountName = null;

  final String? accountName;
  final WalletFailure? failure;

  bool get ok => failure == null;
}

class WithdrawResult {
  const WithdrawResult.requested(
    Withdrawal this.withdrawal, {
    this.earlier = false,
  }) : failure = null,
       unsettled = false;
  const WithdrawResult.failure(
    WalletFailure this.failure, {
    this.unsettled = false,
  }) : withdrawal = null,
       earlier = false;

  final Withdrawal? withdrawal;
  final WalletFailure? failure;

  /// The request may have reached the API and no answer says whether it
  /// was kept, so it is not known to have failed.
  final bool unsettled;

  /// [withdrawal] is the one an earlier request made, whose answer was
  /// lost; the amount asked for now was not sent.
  final bool earlier;

  bool get ok => failure == null;
}

/// Withdrawals and bank checks. Paystack sits behind the iQLY API: the app
/// only ever talks to the API. The demo answers after a short delay.
abstract class WalletService {
  /// The name the bank holds for [accountNumber] at [bankCode].
  Future<VerifyResult> verifyAccount({
    required String bankCode,
    required String accountNumber,
  });

  /// Asks for [amountKobo] to go to [account]. The amount is on hold until
  /// it arrives or fails.
  Future<WithdrawResult> withdraw({
    required int amountKobo,
    required SavedBank account,
  });

  /// [withdrawal] now and every change after (approved, sent, arrived or
  /// failed). The live API pushes or polls; the screen just listens.
  Stream<Withdrawal> watch(Withdrawal withdrawal);

  /// The withdrawal [id] as the API holds it, for a page opened by a link
  /// when the wallet does not hold it; null when there is no such
  /// withdrawal. The demo's are all in its wallet.
  Future<Withdrawal?> withdrawal(String id);

  /// Whether [pin] is the person's 4-digit iQLY PIN.
  Future<bool> confirmPin(String pin);

  /// Saves a verified account; it is not the default until [setDefault].
  Future<SavedBank> addAccount(SavedBank account);

  /// Makes [account] the default payout account. A withdrawal already on
  /// its way still goes where it was sent.
  Future<void> setDefault(SavedBank account);

  /// Removes [account] and answers the accounts left, the default first.
  Future<List<SavedBank>> removeAccount(SavedBank account);
}

/// As on the web demo, an account number ending in 0 cannot be verified;
/// any other ten digits verify as [DemoData.savedBank]'s name. A watched
/// withdrawal on hold is approved, sent and arrives [payoutStep] apart (the
/// Figma tracker hands over to Home after payout at 4 s).
class DemoWalletService implements WalletService {
  DemoWalletService({
    this.delay = const Duration(milliseconds: 700),
    this.payoutStep = const Duration(seconds: 1),
    this.failWith,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Every withdrawal request fails this way while set.
  WalletFailure? failWith;

  static const unverifiableAccountNumber = '0123456780';

  final Duration delay;

  /// Null keeps watched withdrawals where they are.
  final Duration? payoutStep;
  final DateTime Function() _clock;

  final requests = <({int amountKobo, SavedBank account})>[];
  final pins = <String>[];
  final added = <SavedBank>[];
  final defaults = <SavedBank>[];
  final removed = <SavedBank>[];
  int _next = 4;

  Future<void> _wait(Duration duration) => duration == Duration.zero
      ? Future.value()
      : Future<void>.delayed(duration);

  static bool _isAccountNumber(String value) =>
      RegExp(r'^\d{10}$').hasMatch(value);

  @override
  Future<VerifyResult> verifyAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    await _wait(delay);
    if (!_isAccountNumber(accountNumber) || accountNumber.endsWith('0')) {
      return const VerifyResult.failure(WalletFailure.unverified);
    }
    return VerifyResult.verified(DemoData.savedBank.accountName);
  }

  @override
  Future<WithdrawResult> withdraw({
    required int amountKobo,
    required SavedBank account,
  }) async {
    await _wait(delay);
    final failure = failWith;
    if (failure != null) return WithdrawResult.failure(failure);
    requests.add((amountKobo: amountKobo, account: account));
    final now = _clock();
    final id = _next++;
    final random = Random(id);
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final tail = [
      for (var i = 0; i < 4; i++) letters[random.nextInt(letters.length)],
    ].join();
    return WithdrawResult.requested(
      Withdrawal(
        id: 'w$id',
        amountKobo: amountKobo,
        status: WithdrawalStatus.pending,
        createdAt: now,
        reference: 'IQ-WD-${DateFormat('yyMMdd').format(now)}-$tail',
        bankName: account.bankName,
        accountNumber: account.accountNumber,
        held: added.any((a) => a.accountNumber == account.accountNumber),
      ),
    );
  }

  @override
  Future<Withdrawal?> withdrawal(String id) async => null;

  @override
  Stream<Withdrawal> watch(Withdrawal withdrawal) async* {
    yield withdrawal;
    final step = payoutStep;
    if (step == null || !withdrawal.onHold) return;
    var current = withdrawal;
    if (current.held && current.approvedAt == null) {
      await _wait(step);
      current = current.copyWith(
        status: WithdrawalStatus.processing,
        approvedAt: _clock(),
      );
      yield current;
    }
    if (current.sentAt == null) {
      await _wait(step);
      current = current.copyWith(
        status: WithdrawalStatus.processing,
        sentAt: _clock(),
      );
      yield current;
    }
    await _wait(step);
    yield current.copyWith(
      status: WithdrawalStatus.completed,
      completedAt: _clock(),
    );
  }

  /// The demo takes any four digits.
  @override
  Future<bool> confirmPin(String pin) async {
    await _wait(delay);
    pins.add(pin);
    return RegExp(r'^\d{4}$').hasMatch(pin);
  }

  @override
  Future<SavedBank> addAccount(SavedBank account) async {
    await _wait(delay);
    added.add(account);
    return account;
  }

  @override
  Future<void> setDefault(SavedBank account) async {
    await _wait(delay);
    defaults.add(account);
  }

  @override
  Future<List<SavedBank>> removeAccount(SavedBank account) async {
    await _wait(delay);
    removed.add(account);
    return [
      for (final a in added)
        if (a.key != account.key) a,
    ];
  }
}

/// A wallet a live launch pauses: every call refuses before any step of
/// the demo's, and nothing reaches the API.
class PausedWalletService implements WalletService {
  const PausedWalletService();

  @override
  Future<VerifyResult> verifyAccount({
    required String bankCode,
    required String accountNumber,
  }) async => const VerifyResult.failure(WalletFailure.unknown);

  @override
  Future<WithdrawResult> withdraw({
    required int amountKobo,
    required SavedBank account,
  }) async => const WithdrawResult.failure(WalletFailure.unknown);

  @override
  Stream<Withdrawal> watch(Withdrawal withdrawal) => Stream.value(withdrawal);

  @override
  Future<Withdrawal?> withdrawal(String id) =>
      Future.error(const FeaturePaused(LiveFeature.withdrawals));

  @override
  Future<bool> confirmPin(String pin) async => false;

  @override
  Future<SavedBank> addAccount(SavedBank account) =>
      Future.error(const FeaturePaused(LiveFeature.wallet));

  @override
  Future<void> setDefault(SavedBank account) =>
      Future.error(const FeaturePaused(LiveFeature.wallet));

  @override
  Future<List<SavedBank>> removeAccount(SavedBank account) =>
      Future.error(const FeaturePaused(LiveFeature.wallet));
}

/// The demo in a preview launch. In a live one the API runs the wallet,
/// and withdrawals while they are live too; a paused wallet refuses. Made
/// again for each signed-in person, so a withdrawal one of them left
/// unsettled is never sent for another.
final walletServiceProvider = Provider<WalletService>((ref) {
  final scope = ref.watch(accountScopeProvider);
  final api = ref.watch(apiClientProvider);
  final mode = ref.watch(liveModeProvider);
  if (api == null || mode.isPreview) return DemoWalletService();
  if (!mode.isLive(LiveFeature.wallet)) return const PausedWalletService();
  return LiveWalletService(
    api,
    withdrawals: mode.isLive(LiveFeature.withdrawals),
    bankAccounts: mode.isLive(LiveFeature.bankAccounts),
    scope: scope,
  );
});
