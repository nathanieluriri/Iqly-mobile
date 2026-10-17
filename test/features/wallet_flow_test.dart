import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/wallet_service.dart';
import 'package:iqly_mobile/features/discover/app_shell.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/wallet/activity_screen.dart';
import 'package:iqly_mobile/features/wallet/add_bank_screen.dart';
import 'package:iqly_mobile/features/wallet/bank_account_sheet.dart';
import 'package:iqly_mobile/features/wallet/pin_sheet.dart';
import 'package:iqly_mobile/features/wallet/select_bank_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_balance_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_overview.dart';
import 'package:iqly_mobile/features/wallet/wallet_routes.dart';
import 'package:iqly_mobile/features/wallet/wallet_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_state.dart';
import 'package:iqly_mobile/features/wallet/withdraw_sheet.dart';
import 'package:iqly_mobile/features/wallet/withdrawal_pending_screen.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_failed_screen.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_tracker_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/field.dart';
import 'package:iqly_mobile/ui/list_row.dart';
import 'package:iqly_mobile/ui/pressable.dart';
import 'package:iqly_mobile/ui/wallet_card.dart';
import 'package:iqly_mobile/ui/wallet_row.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/wallet_harness.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  final rect = tester.getRect(finder);
  if (rect.top < 0 || rect.bottom > 810) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

Finder _back() => find.byWidgetPredicate(
  (w) => w is IqPressable && w.semanticLabel == 'Back',
);

Finder _field(String label) =>
    find.byWidgetPredicate((w) => w is IqField && w.label == label);

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.enterText(
    find.descendant(of: _field(label), matching: find.byType(EditableText)),
    text,
  );
  await tester.pumpAndSettle();
}

IqWalletCard _card(WidgetTester tester) =>
    tester.widget<IqWalletCard>(find.byType(IqWalletCard));

IqButton _button(WidgetTester tester, String label) => tester.widget<IqButton>(
  find.byWidgetPredicate((w) => w is IqButton && w.label == label),
);

void main() {
  testWidgets('B5: every figure foots to the demo data', (tester) async {
    await pumpApp(
      tester,
      Routes.wallet,
      repository: WalletRepository(),
      overrides: walletOverrides(),
    );
    expect(find.byType(AppShell), findsOneWidget);
    expect(_card(tester).amount, '₦15,000.00');
    expect(
      find.text('₦10,000.00 on its way · ₦65,000.00 earned so far'),
      findsOneWidget,
    );
    expect(find.byType(IqWalletRow), findsNWidgets(recentRows));
    expect(find.text('Private business'), findsOneWidget);
    expect(find.text('Kudi Box'), findsOneWidget);
    expect(find.text('Reward · activation · step 2 confirmed'), findsOneWidget);
    expect(find.text('Referral bonus'), findsOneWidget);
    expect(find.text('Failed · nothing left your wallet'), findsOneWidget);
  });

  testWidgets('B5: the balance tabs switch the card in place, dock kept; '
      'the eye hides the figures', (tester) async {
    await pumpApp(
      tester,
      Routes.wallet,
      repository: WalletRepository(),
      overrides: walletOverrides(),
    );
    await _tap(tester, find.text('On its way'));
    expect(_card(tester).balance, IqWalletCardBalance.onItsWay);
    expect(_card(tester).amount, '₦10,000.00');
    expect(find.byType(WalletScreen), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);
    await _tap(tester, find.text('Earned'));
    expect(_card(tester).amount, '₦65,000.00');
    expect(find.text('From 2 winning submissions'), findsOneWidget);
    expect(find.text('Recent rewards'), findsOneWidget);

    await tester.tap(find.byType(IqWalletCard));
    await _settle(tester);
    expect(find.byType(WalletBalanceScreen), findsNothing);

    await _tap(
      tester,
      find.byWidgetPredicate(
        (w) => w is IqPressable && w.semanticLabel == 'Hide balance',
      ),
    );
    expect(_card(tester).visibility, IqWalletCardVisibility.hidden);
    expect(find.text('+₦ • • • •'), findsWidgets);
  });

  testWidgets('B5: withdraw ₦5,000.00 through the PIN, Done back to the '
      'Wallet', (tester) async {
    final wallet = instantWallet();
    await pumpApp(
      tester,
      Routes.wallet,
      repository: WalletRepository(),
      overrides: walletOverrides(wallet: wallet),
    );
    await _tap(tester, find.text('Withdraw'));
    expect(find.byType(WithdrawSheet), findsOneWidget);
    expect(
      find.text('You can withdraw up to ₦15,000.00 right now'),
      findsOneWidget,
    );
    await _type(tester, 'Amount', '5000');
    await _tap(tester, find.text('Withdraw').last);
    expect(find.byType(PinSheet), findsOneWidget);
    expect(
      find.text(
        '₦5,000.00 to Access Bank ••6789. Your 4-digit iQLY PIN confirms '
        'every withdrawal.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('instead'), findsNothing);
    await _type(tester, 'iQLY PIN', '1234');
    await _tap(tester, find.text('Confirm withdrawal'));
    expect(wallet.pins, ['1234']);
    expect(wallet.requests.single.amountKobo, 500000);
    expect(find.byType(WithdrawalPendingScreen), findsOneWidget);
    expect(find.text('₦5,000.00 is on its way'), findsOneWidget);
    expect(find.text('₦10,000.00'), findsOneWidget);

    await _tap(tester, find.text('Done'));
    expect(find.byType(WalletScreen), findsOneWidget);
    expect(_card(tester).amount, '₦10,000.00');
  });

  testWidgets('B5: above available and below the minimum', (tester) async {
    await pumpApp(
      tester,
      Routes.withdraw,
      repository: WalletRepository(),
      overrides: walletOverrides(),
    );
    await _settle(tester);
    await _type(tester, 'Amount', '20000');
    expect(find.text('You have ₦15,000.00 available.'), findsOneWidget);
    expect(_button(tester, 'Withdraw').disabled, isTrue);
    await _type(tester, 'Amount', '500');
    await _tap(tester, find.text('Withdraw').last);
    expect(find.text('Minimum withdrawal is ₦1,000.00.'), findsOneWidget);
    expect(find.byType(PinSheet), findsNothing);
  });

  testWidgets('B5: ₦500.00 left goes whole through the PIN; any other amount '
      'under ₦1,000 stays below the minimum (contract 6)', (tester) async {
    final wallet = instantWallet();
    await pumpApp(
      tester,
      Routes.wallet,
      repository: WalletRepository(),
      overrides: walletOverrides(wallet: wallet),
    );
    await _tap(tester, find.text('Withdraw'));
    await _type(tester, 'Amount', '14500');
    await _tap(tester, find.text('Withdraw').last);
    await _type(tester, 'iQLY PIN', '1234');
    await _tap(tester, find.text('Confirm withdrawal'));
    await _tap(tester, find.text('Done'));
    expect(_card(tester).amount, '₦500.00');

    await _tap(tester, find.text('Withdraw'));
    expect(
      find.text('You can withdraw up to ₦500.00 right now'),
      findsOneWidget,
    );
    await _type(tester, 'Amount', '300');
    await _tap(tester, find.text('Withdraw').last);
    expect(find.text('Minimum withdrawal is ₦1,000.00.'), findsOneWidget);
    expect(find.byType(PinSheet), findsNothing);

    await _type(tester, 'Amount', '500');
    expect(find.text('Minimum withdrawal is ₦1,000.00.'), findsNothing);
    await _tap(tester, find.text('Withdraw').last);
    await _type(tester, 'iQLY PIN', '1234');
    await _tap(tester, find.text('Confirm withdrawal'));
    expect([for (final r in wallet.requests) r.amountKobo], [1450000, 50000]);
    expect(find.byType(WithdrawalPendingScreen), findsOneWidget);
    expect(find.text('₦500.00 is on its way'), findsOneWidget);
  });

  testWidgets('B5: no connection keeps the sheet; Try again sends', (
    tester,
  ) async {
    final wallet = instantWallet()..failWith = WalletFailure.offline;
    await pumpApp(
      tester,
      withdrawLocation(amountKobo: 500000),
      repository: WalletRepository(),
      overrides: walletOverrides(wallet: wallet),
    );
    await _settle(tester);
    await _tap(tester, find.text('Withdraw').last);
    await _type(tester, 'iQLY PIN', '1234');
    await _tap(tester, find.text('Confirm withdrawal'));
    expect(find.text('No connection. Nothing was sent.'), findsOneWidget);
    expect(find.byType(WithdrawSheet), findsOneWidget);
    wallet.failWith = null;
    await _tap(tester, find.text('Try again'));
    expect(find.byType(WithdrawalPendingScreen), findsOneWidget);
  });

  testWidgets('B5: To picks another saved account', (tester) async {
    final wallet = instantWallet();
    await pumpApp(
      tester,
      withdrawLocation(amountKobo: 500000),
      repository: WalletRepository(),
      overrides: walletOverrides(wallet: wallet),
    );
    await _settle(tester);
    await _tap(tester, find.text('Access Bank ••6789 · ADAEZE OKAFOR'));
    expect(find.byType(BankAccountSheet), findsOneWidget);
    expect(find.text('Set as default'), findsNothing);
    await _tap(tester, find.text('Guaranty Trust Bank ••4410'));
    expect(find.byType(BankAccountSheet), findsNothing);
    expect(
      find.text('Guaranty Trust Bank ••4410 · ADAEZE OKAFOR'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Withdraw').last);
    await _type(tester, 'iQLY PIN', '1234');
    await _tap(tester, find.text('Confirm withdrawal'));
    expect(wallet.requests.single.account.bankName, 'Guaranty Trust Bank');
  });

  testWidgets('B5: Set as default asks for the PIN, then switches', (
    tester,
  ) async {
    final wallet = instantWallet();
    final container = await pumpApp(
      tester,
      Routes.wallet,
      repository: WalletRepository(),
      overrides: walletOverrides(wallet: wallet),
    );
    await _tap(tester, find.text('Bank account'));
    expect(find.text('Set as default'), findsNothing);
    expect(find.text('Adaeze Okafor · Default'), findsOneWidget);
    expect(find.textContaining('Name verified'), findsNothing);
    await _tap(tester, find.text('Guaranty Trust Bank ••4410'));
    expect(
      find.text(
        'Your pending ₦10,000.00 still goes to Access Bank ••6789. We ask '
        'for your PIN before switching.',
      ),
      findsOneWidget,
    );
    await _tap(tester, find.text('Access Bank ••6789'));
    expect(find.text('Set as default'), findsNothing);
    await _tap(tester, find.text('Guaranty Trust Bank ••4410'));
    await _tap(tester, find.text('Set as default'));
    expect(find.byType(PinSheet), findsOneWidget);
    await _type(tester, 'iQLY PIN', '1234');
    await _tap(tester, find.text('Set as default').last);
    expect(find.byType(BankAccountSheet), findsNothing);
    expect(wallet.defaults.single.bankName, 'Guaranty Trust Bank');
    expect(
      container.read(walletProvider).value!.savedBank!.label,
      'Guaranty Trust Bank ••4410',
    );
  });

  testWidgets('B5: Add a bank account: pick, check the name, save, back on '
      'the sheet', (tester) async {
    final wallet = instantWallet();
    await pumpApp(
      tester,
      Routes.wallet,
      repository: WalletRepository(),
      overrides: walletOverrides(wallet: wallet),
    );
    await _tap(tester, find.text('Bank account'));
    await _tap(tester, find.text('Add a bank account'));
    expect(find.byType(SelectBankScreen), findsOneWidget);
    await _tap(tester, find.widgetWithText(IqListRow, 'Kuda Bank'));
    expect(find.byType(AddBankScreen), findsOneWidget);
    await _type(tester, 'Account number', '0123456780');
    await _tap(tester, find.text('Check the name'));
    expect(find.text(verifyHelp), findsOneWidget);
    await _type(tester, 'Account number', '1234567891');
    await _tap(tester, find.text('Check the name'));
    expect(find.text('ADAEZE OKAFOR'), findsOneWidget);
    expect(find.textContaining('Name verified'), findsNothing);
    expect(find.text('Kuda Bank · 10 digits'), findsOneWidget);
    await _tap(tester, find.text('Save account'));
    expect(find.byType(AddBankScreen), findsNothing);
    expect(find.byType(SelectBankScreen), findsNothing);
    expect(find.byType(BankAccountSheet), findsOneWidget);
    expect(find.text('Kuda Bank ••7891'), findsOneWidget);
    expect(wallet.added.single.accountNumber, '1234567891');
  });

  testWidgets('B5: See all opens Activity; tabs and the filter count', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.wallet,
      repository: WalletRepository(),
      overrides: walletOverrides(),
    );
    await _tap(tester, find.text('See all'));
    expect(find.byType(ActivityScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    expect(find.text('9 results'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    await _tap(tester, find.text('Rewards'));
    expect(find.text('5 results'), findsOneWidget);
    await _tap(tester, find.text('Withdrawals').first);
    expect(find.text('4 results'), findsOneWidget);
    await _tap(tester, find.text('Filter'));
    await _tap(tester, find.text('Reversed'));
    expect(find.text('Show 1 results'), findsOneWidget);
    await _tap(tester, find.text('Show 1 results'));
    expect(find.text('Reversed · back in your wallet'), findsOneWidget);
    expect(find.text('1 results'), findsOneWidget);

    await _tap(tester, _back());
    expect(find.byType(WalletScreen), findsOneWidget);
  });

  testWidgets('B14: rows open the tracker, failed and reversed pages; back '
      'returns to the opener', (tester) async {
    await pumpApp(
      tester,
      activityPath(),
      repository: WalletRepository(),
      overrides: walletOverrides(),
    );
    await _tap(tester, find.text('Pending'));
    expect(find.byType(WithdrawalTrackerScreen), findsOneWidget);
    expect(find.text('Awaiting approval'), findsNothing);
    final router = GoRouter.of(
      tester.element(find.byType(WithdrawalTrackerScreen)),
    );
    expect(router.state.uri.path, withdrawalPath('w3'));
    await _tap(tester, _back());
    expect(find.byType(ActivityScreen), findsOneWidget);

    await _tap(tester, find.text('Reversed · back in your wallet'));
    expect(find.byType(WithdrawalFailedScreen), findsOneWidget);
    expect(
      find.text('The bank sent it back. Back in your wallet.'),
      findsOneWidget,
    );
    expect(find.text('Reversed by the bank'), findsOneWidget);
    await _tap(tester, find.text('Fix bank account'));
    expect(find.byType(SelectBankScreen), findsOneWidget);
    await _tap(tester, _back());
    expect(find.byType(WithdrawalFailedScreen), findsOneWidget);
  });

  testWidgets('B14: arrived reads the bank and the time', (tester) async {
    await pumpApp(
      tester,
      withdrawalPath('w3'),
      repository: ArrivedWalletRepository(),
      overrides: walletOverrides(),
    );
    expect(find.text('Arrived'), findsWidgets);
    expect(
      find.text('Arrived at Access Bank ••6789 · Today, 3:06 pm'),
      findsOneWidget,
    );
  });

  testWidgets('B14: Home shows the payout row and it pushes the withdrawal', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.home,
      repository: PaidOutWalletRepository(),
      overrides: walletOverrides(),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    await _tap(tester, find.text('₦10,000.00 completed'));
    expect(find.byType(WithdrawalTrackerScreen), findsOneWidget);
    await _tap(tester, _back());
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('B5: failed to load, Try again loads the wallet', (tester) async {
    final repository = FailingWalletRepository();
    await pumpApp(
      tester,
      Routes.wallet,
      repository: repository,
      overrides: walletOverrides(),
    );
    expect(find.text('Couldn\'t load your wallet'), findsOneWidget);
    repository.fail = false;
    await _tap(tester, find.text('Try again'));
    expect(find.byType(IqWalletCard), findsOneWidget);
  });

  testWidgets('B5: no activity: zeros, Withdraw disabled', (tester) async {
    await pumpApp(
      tester,
      Routes.wallet,
      repository: EmptyWalletRepository(),
      overrides: walletOverrides(),
    );
    expect(find.text('No activity yet'), findsOneWidget);
    expect(_card(tester).amount, '₦0.00');
    expect(find.text('Win a brief to start earning'), findsOneWidget);
    await tester.tap(find.text('Withdraw'));
    await _settle(tester);
    expect(find.byType(WithdrawSheet), findsNothing);
  });

  for (final path in [
    walletOnItsWayPath,
    walletEarnedPath,
    activityPath(),
    Routes.selectBank,
    addBankPath('044'),
    withdrawalPath('w3'),
  ]) {
    testWidgets('$path: a sub page, Page bar with Back, no dock', (
      tester,
    ) async {
      await pumpApp(
        tester,
        path,
        repository: WalletRepository(),
        overrides: walletOverrides(),
      );
      await _settle(tester);
      expect(find.byType(AppShell), findsNothing);
      expect(_back(), findsOneWidget);
    });
  }

  for (final (name, location) in [
    ('wallet', Routes.wallet),
    ('activity', activityPath()),
    ('tracker', withdrawalPath('w3')),
    ('failed', withdrawalPath('w1')),
    ('bank account', bankAccountPath),
  ]) {
    testWidgets('$name: every target labelled', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        location,
        repository: WalletRepository(),
        overrides: walletOverrides(),
      );
      await _settle(tester);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }

  test('the referral copy stays with the demo data', () {
    expect(
      DemoData().ledger.where((l) => l.note?.contains('won a first') ?? false),
      hasLength(2),
    );
  });
}
