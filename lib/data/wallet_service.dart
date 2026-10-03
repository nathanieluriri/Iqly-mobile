import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'demo_data.dart';
import 'models.dart';

/// Why a wallet call failed. The live API layer maps its codes onto these.
enum WalletFailure {
  /// The bank could not match the account number to a name.
  unverified,
  offline,
  unknown,
}

class VerifyResult {
  const VerifyResult.verified(String this.accountName) : failure = null;
  const VerifyResult.failure(WalletFailure this.failure) : accountName = null;

  final String? accountName;
  final WalletFailure? failure;

  bool get ok => failure == null;
}

class WithdrawResult {
  const WithdrawResult.requested(Withdrawal this.withdrawal) : failure = null;
  const WithdrawResult.failure(WalletFailure this.failure) : withdrawal = null;

  final Withdrawal? withdrawal;
  final WalletFailure? failure;

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
}

/// As on the web demo, an account number ending in 0 cannot be verified;
/// any other ten digits verify as [DemoData.savedBank]'s name. A watched
/// withdrawal on hold is approved, sent and arrives [payoutStep] apart (the
/// Figma tracker hands over to Home after payout at 4 s).
class DemoWalletService implements WalletService {
  DemoWalletService({
    this.delay = const Duration(milliseconds: 700),
    this.payoutStep = const Duration(seconds: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const unverifiableAccountNumber = '0123456780';

  final Duration delay;

  /// Null keeps watched withdrawals where they are.
  final Duration? payoutStep;
  final DateTime Function() _clock;

  final requests = <({int amountKobo, SavedBank account})>[];
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
      ),
    );
  }

  @override
  Stream<Withdrawal> watch(Withdrawal withdrawal) async* {
    yield withdrawal;
    final step = payoutStep;
    if (step == null || !withdrawal.onHold) return;
    var current = withdrawal;
    if (current.approvedAt == null) {
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
}

final walletServiceProvider = Provider<WalletService>(
  (ref) => DemoWalletService(),
);
