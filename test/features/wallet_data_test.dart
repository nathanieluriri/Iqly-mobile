import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/money.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/wallet_service.dart';
import 'package:iqly_mobile/features/wallet/wallet_format.dart';
import 'package:iqly_mobile/features/wallet/wallet_state.dart';
import 'package:iqly_mobile/features/withdrawals/payout_arrival.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_failed_screen.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_widgets.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/wallet_harness.dart';

TextEditingValue _typed(String text) => const NairaInputFormatter()
    .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text));

ProviderContainer _container({IqlyRepository? repository}) {
  final container = ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(repository ?? WalletRepository()),
      clockProvider.overrideWithValue(() => figmaNow),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('amount', () {
    test('parses what the field holds, to the kobo', () {
      expect(parseNaira('₦5,000'), 500000);
      expect(parseNaira('₦5,000.00'), 500000);
      expect(parseNaira('5000.5'), 500050);
      expect(parseNaira('₦12,500.01'), 1250001);
      expect(parseNaira(''), isNull);
      expect(parseNaira('₦'), isNull);
      expect(parseNaira('5.000.00'), isNull);
    });

    test('formats as it is typed', () {
      expect(_typed('5000').text, '₦5,000');
      expect(_typed('₦12500.5').text, '₦12,500.5');
      expect(_typed('12500.567').text, '₦12,500.56');
      expect(_typed('007').text, '₦7');
      expect(_typed('.5').text, '₦0.5');
      expect(_typed('').text, '');
      expect(_typed('abc').text, '');
      final value = _typed('1000');
      expect(value.selection.baseOffset, value.text.length);
    });

    test(
      'follows the web rule: at least ₦1,000, at most what is available',
      () {
        const available = 1250000;
        expect(validWithdrawal(null, available), isFalse);
        expect(validWithdrawal(99999, available), isFalse);
        expect(validWithdrawal(100000, available), isTrue);
        expect(validWithdrawal(1250000, available), isTrue);
        expect(validWithdrawal(1250001, available), isFalse);
      },
    );

    test('splits the hero figure into naira and kobo', () {
      expect(nairaParts(1250000), ('₦12,500', '.00'));
      expect(nairaParts(750050), ('₦7,500', '.50'));
      expect(nairaParts(0), ('₦0', '.00'));
    });
  });

  test('receipt and step times read as Figma writes them', () {
    final data = DemoData(now: figmaNow);
    final pending = data.withdrawals.singleWhere((w) => w.id == 'w3');
    final failed = data.withdrawals.singleWhere((w) => w.id == 'w1');
    expect(withdrawalTime(pending.createdAt, figmaNow), 'Today, 7:40 am');
    expect(withdrawalTime(failed.createdAt, figmaNow), '11 days ago, 2:05 pm');
    expect(
      withdrawalTime(failed.approvedAt!, figmaNow),
      '11 days ago, 4:40 pm',
    );
    expect(
      withdrawalTime(figmaNow.subtract(const Duration(days: 1)), figmaNow),
      '1 day ago, 9:41 am',
    );
    expect(capitalized('pending'), 'Pending');
  });

  group('withdrawals', () {
    test('show the product words; processing reads pending', () {
      Withdrawal of(WithdrawalStatus status) => Withdrawal(
        id: 'w',
        amountKobo: 1,
        status: status,
        createdAt: figmaNow,
      );
      expect(of(WithdrawalStatus.pending).statusWord, 'pending');
      expect(of(WithdrawalStatus.processing).statusWord, 'pending');
      expect(of(WithdrawalStatus.completed).statusWord, 'completed');
      expect(of(WithdrawalStatus.failed).statusWord, 'failed');
      expect(of(WithdrawalStatus.reversed).statusWord, 'reversed');
      expect(of(WithdrawalStatus.processing).onHold, isTrue);
      expect(of(WithdrawalStatus.reversed).failed, isTrue);
    });

    test('the demo rows carry the B14 receipts', () {
      final data = DemoData(now: figmaNow);
      final byId = {for (final w in data.withdrawals) w.id: w};
      expect(byId['w3']!.reference, 'IQ-WD-241003-9A2M');
      expect(byId['w3']!.destination, 'Access Bank ••6789');
      expect(byId['w1']!.reference, 'IQ-WD-240922-3C7Q');
      expect(
        WithdrawalFailedScreen.reasonLine(byId['w1']!),
        'Account name didn’t match. Nothing left your wallet.',
      );
      expect(
        WithdrawalFailedScreen.reasonLine(byId['w0']!),
        'The bank sent it back. Back in your wallet.',
      );
    });

    test('steps done follow transfer and arrival; approval only when held', () {
      final w = DemoData(now: figmaNow).withdrawals.first;
      expect(w.held, isFalse);
      expect(withdrawalStepsDone(w), 1);
      expect(withdrawalStepsDone(w.copyWith(sentAt: figmaNow)), 2);
      expect(
        withdrawalStepsDone(w.copyWith(status: WithdrawalStatus.completed)),
        3,
      );
      expect(
        [for (final s in withdrawalSteps(w, figmaNow)) s.title],
        ['Requested', 'Sent to your bank', 'Arrived'],
      );
      final held = Withdrawal(
        id: 'h',
        amountKobo: 1,
        status: WithdrawalStatus.pending,
        createdAt: figmaNow,
        held: true,
      );
      expect(
        [for (final s in withdrawalSteps(held, figmaNow)) s.title],
        ['Requested', 'Awaiting approval', 'Sent to your bank', 'Arrived'],
      );
      expect(withdrawalStepsDone(held.copyWith(approvedAt: figmaNow)), 2);
      final byId = {
        for (final x in DemoData(now: figmaNow).withdrawals) x.id: x,
      };
      expect(
        [for (final s in withdrawalSteps(byId['w1']!, figmaNow)) s.title],
        ['Requested', 'Approved by iQLY', 'Failed at the bank'],
      );
      expect(
        [for (final s in withdrawalSteps(byId['w0']!, figmaNow)) s.title],
        ['Requested', 'Sent to your bank', 'Reversed by the bank'],
      );
    });
  });

  group('DemoWalletService', () {
    test('verifies ten digits unless they end in 0, as the web demo', () async {
      final service = instantWallet();
      final ok = await service.verifyAccount(
        bankCode: '50211',
        accountNumber: '0123456789',
      );
      expect(ok.accountName, 'ADAEZE OKAFOR');
      final bad = await service.verifyAccount(
        bankCode: '50211',
        accountNumber: DemoWalletService.unverifiableAccountNumber,
      );
      expect(bad.failure, WalletFailure.unverified);
      final short = await service.verifyAccount(
        bankCode: '50211',
        accountNumber: '01234',
      );
      expect(short.ok, isFalse);
    });

    test('a request comes back pending, to the account asked for', () async {
      final service = instantWallet();
      final result = await service.withdraw(
        amountKobo: 500000,
        account: DemoData.savedBank,
      );
      final w = result.withdrawal!;
      expect(w.id, 'w4');
      expect(w.status, WithdrawalStatus.pending);
      expect(w.createdAt, figmaNow);
      expect(w.destination, 'Access Bank ••6789');
      expect(w.reference, startsWith('IQ-WD-261003-'));
    });

    test('a watched one on hold is sent and arrives', () async {
      final service = DemoWalletService(
        delay: Duration.zero,
        payoutStep: Duration.zero,
        clock: () => figmaNow,
      );
      final pending = DemoData(now: figmaNow).withdrawals.first;
      final seen = await service.watch(pending).toList();
      expect(seen.map((w) => w.status), [
        WithdrawalStatus.pending,
        WithdrawalStatus.processing,
        WithdrawalStatus.completed,
      ]);
      final held = await service
          .watch(
            Withdrawal(
              id: pending.id,
              amountKobo: pending.amountKobo,
              status: pending.status,
              createdAt: pending.createdAt,
              held: true,
            ),
          )
          .toList();
      expect(held.length, 4);
      expect(held[1].approvedAt, figmaNow);
      expect(seen.last.completedAt, figmaNow);
      expect(await instantWallet().watch(pending).length, 1);
    });
  });

  group('wallet state', () {
    test('activity is rewards and withdrawals, newest first', () async {
      final container = _container();
      final data = await container.read(walletProvider.future);
      expect(
        [
          for (final item in data.activity)
            item.award?.amountKobo ?? item.withdrawal!.amountKobo,
        ],
        [
          1000000,
          1250000,
          150000,
          50000,
          4000000,
          500000,
          5000000,
          200000,
          50000,
        ],
      );
      expect(data.savedBank?.label, 'Access Bank ••6789');
      expect(data.accounts.map((a) => a.label), [
        'Access Bank ••6789',
        'Guaranty Trust Bank ••4410',
      ]);
      expect(data.onHoldCount, 1);
      expect(data.winningSubmissions, 2);
    });

    test('the demo foots: ₦65,000.00 earned, ₦15,000.00 available', () async {
      final container = _container();
      final data = await container.read(walletProvider.future);
      final totals = data.totals;
      expect(naira(totals.totalEarnedKobo), '₦65,000.00');
      expect(naira(totals.pendingWithdrawalsKobo), '₦10,000.00');
      expect(naira(totals.withdrawableKobo), '₦15,000.00');
      final paidOut = data.withdrawals
          .where((w) => w.status == WithdrawalStatus.completed)
          .fold(0, (sum, w) => sum + w.amountKobo);
      expect(
        totals.totalEarnedKobo,
        paidOut + totals.pendingWithdrawalsKobo + totals.withdrawableKobo,
      );
      expect({
        for (final l in data.ledger)
          if (l.type == LedgerType.award) l.source,
      }, RewardSource.values.toSet());
    });

    test('figures foot through a withdrawal and its arrival', () async {
      final container = _container();
      final notifier = container.read(walletProvider.notifier);
      final before = (await container.read(walletProvider.future)).totals;
      expect(naira(before.withdrawableKobo), '₦15,000.00');

      final requested = (await instantWallet().withdraw(
        amountKobo: 500000,
        account: DemoData.savedBank,
      )).withdrawal!;
      notifier.add(requested);
      var totals = container.read(walletProvider).value!.totals;
      expect(naira(totals.withdrawableKobo), '₦10,000.00');
      expect(naira(totals.pendingWithdrawalsKobo), '₦15,000.00');
      expect(naira(totals.totalEarnedKobo), '₦65,000.00');

      notifier.replace(
        requested.copyWith(
          status: WithdrawalStatus.completed,
          completedAt: figmaNow,
        ),
      );
      totals = container.read(walletProvider).value!.totals;
      expect(naira(totals.withdrawableKobo), '₦10,000.00');
      expect(naira(totals.pendingWithdrawalsKobo), '₦10,000.00');
      final data = container.read(walletProvider).value!;
      final paidOut = data.withdrawals
          .where((w) => w.status == WithdrawalStatus.completed)
          .fold(0, (sum, w) => sum + w.amountKobo);
      expect(
        totals.totalEarnedKobo,
        paidOut + totals.pendingWithdrawalsKobo + totals.withdrawableKobo,
      );
    });

    test(
      'a new account joins after the default; switching moves it first',
      () async {
        final container = _container();
        final notifier = container.read(walletProvider.notifier);
        await container.read(walletProvider.future);
        const kuda = SavedBank(
          bankCode: '50211',
          bankName: 'Kuda Bank',
          accountName: 'ADAEZE OKAFOR',
          accountNumber: '1234567891',
        );
        notifier.addAccount(kuda);
        expect(
          container.read(walletProvider).value!.accounts.last.label,
          'Kuda Bank ••7891',
        );
        notifier.setDefault(kuda);
        final data = container.read(walletProvider).value!;
        expect(data.savedBank, kuda);
        expect(data.accounts.length, 3);
        expect(kuda.holder, 'Adaeze Okafor');
      },
    );

    test('a failed withdrawal releases its hold', () async {
      final container = _container();
      final notifier = container.read(walletProvider.notifier);
      final data = await container.read(walletProvider.future);
      final pending = data.withdrawal('w3')!;
      notifier.replace(pending.copyWith(status: WithdrawalStatus.failed));
      final totals = container.read(walletProvider).value!.totals;
      expect(naira(totals.withdrawableKobo), '₦25,000.00');
      expect(totals.pendingWithdrawalsKobo, 0);
    });

    test('Home shows a payout for a day after it arrives', () async {
      final container = _container(repository: PaidOutWalletRepository());
      await container.read(walletProvider.future);
      expect(container.read(recentPayoutProvider)?.id, 'w3');

      final quiet = _container();
      await quiet.read(walletProvider.future);
      expect(quiet.read(recentPayoutProvider), isNull);
    });
  });
}
