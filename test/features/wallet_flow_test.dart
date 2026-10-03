import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/share_service.dart';
import 'package:iqly_mobile/data/wallet_service.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/wallet/select_bank_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_screen.dart';
import 'package:iqly_mobile/features/wallet/withdraw_sheet.dart';
import 'package:iqly_mobile/features/wallet/withdrawal_pending_screen.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_failed_screen.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_tracker_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/balance_hero.dart';
import 'package:iqly_mobile/ui/dock.dart';
import 'package:iqly_mobile/ui/field.dart';
import 'package:iqly_mobile/ui/list_row.dart';
import 'package:iqly_mobile/ui/timeline_row.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/wallet_harness.dart';
import 'entry_harness.dart' show recordHaptics;

const _success = 'HapticFeedbackType.successNotification';
const _commit = 'HapticFeedbackType.lightImpact';
const _error = 'HapticFeedbackType.mediumImpact';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Lets the sheet rise and take focus, or the Wallet catch up after a page
/// on top of it leaves.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

Finder _amountField() => find.byWidgetPredicate(
  (w) => w is IqField && w.kind == IqFieldKind.text && w.label == 'Amount',
);

Finder _accountField() =>
    find.byWidgetPredicate((w) => w is IqField && w.label == 'Account number');

Future<void> _type(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(
    find.descendant(of: field, matching: find.byType(EditableText)),
    text,
  );
  await tester.pumpAndSettle();
}

IqBalanceHero _hero(WidgetTester tester) =>
    tester.widget<IqBalanceHero>(find.byType(IqBalanceHero));

void main() {
  testWidgets('B5: withdraw ₦5,000.00 to the saved bank and back to wallet', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    final wallet = instantWallet();
    await pumpApp(
      tester,
      Routes.wallet,
      repository: WalletRepository(),
      overrides: walletOverrides(wallet: wallet),
    );
    expect(find.byType(WalletScreen), findsOneWidget);
    expect(find.text('Access Bank ••6789'), findsOneWidget);
    expect(_hero(tester).amount, '₦12,500');
    expect(_hero(tester).decimals, '.00');
    expect(_hero(tester).onHold, '₦10,000.00');
    expect(_hero(tester).earned, '₦62,500.00');
    expect(find.text('ON HOLD · 1 PENDING'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    for (final row in [
      '₦10,000.00',
      '+₦12,500.00',
      '₦40,000.00',
      '₦5,000.00',
      '+₦50,000.00',
    ]) {
      await tester.ensureVisible(find.text(row).last);
      expect(find.text(row), findsWidgets);
    }
    expect(find.text('2h ago'), findsOneWidget);
    expect(find.text('pending'), findsOneWidget);
    expect(find.text('completed'), findsOneWidget);
    expect(find.text('failed'), findsOneWidget);

    await _tap(tester, find.text('Withdraw'));
    await _settle(tester);
    expect(find.byType(WithdrawSheet), findsOneWidget);
    expect(find.text('Amount next · bank saved'), findsOneWidget);
    expect(find.text('Access Bank ••6789 · ADAEZE OKAFOR'), findsOneWidget);
    expect(find.text('1 to 2 business days'), findsOneWidget);
    expect(haptics, [_commit]);

    await _type(tester, _amountField(), '5000');
    expect(find.text('₦5,000'), findsOneWidget);
    expect(find.text('Ready · bank saved'), findsOneWidget);

    await _tap(tester, find.text('Access Bank ••6789 · ADAEZE OKAFOR'));
    expect(find.byType(SelectBankScreen), findsOneWidget);
    expect(find.text('Saved · ADAEZE OKAFOR'), findsOneWidget);
    await _tap(tester, find.text('Access Bank'));
    expect(find.byType(SelectBankScreen), findsNothing);
    expect(find.byType(WithdrawSheet), findsOneWidget);
    expect(find.text('Ready · bank saved'), findsOneWidget);

    await _tap(tester, find.text('Withdraw').last);
    expect(find.byType(WithdrawalPendingScreen), findsOneWidget);
    expect(find.byType(WithdrawSheet), findsNothing);
    expect(find.text('Withdrawal pending'), findsOneWidget);
    expect(find.text('₦5,000.00'), findsOneWidget);
    expect(find.text('to Access Bank ••6789'), findsOneWidget);
    expect(find.text('AVAILABLE AFTER'), findsOneWidget);
    expect(find.text('₦7,500.00'), findsOneWidget);
    expect(wallet.requests.single.amountKobo, 500000);
    expect(wallet.requests.single.account.accountNumber, '0123456789');
    expect(haptics, [_commit, _commit, _success]);

    await _tap(tester, find.text('Back to wallet'));
    await _settle(tester);
    expect(find.byType(WithdrawalPendingScreen), findsNothing);
    expect(_hero(tester).amount, '₦7,500');
    expect(_hero(tester).onHold, '₦15,000.00');
    expect(_hero(tester).earned, '₦62,500.00');
    expect(find.text('ON HOLD · 2 PENDING'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Just now'), findsOneWidget);
    expect(find.text('pending'), findsNWidgets(2));
  });

  testWidgets('B5: the bell and the dock leave the Wallet', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      Routes.wallet,
      repository: WalletRepository(),
      overrides: walletOverrides(),
    );
    await _tap(tester, find.bySemanticsLabel(RegExp('^Notifications')));
    expect(find.text('Notifications'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(WalletScreen), findsOneWidget);
    await _tap(
      tester,
      find.descendant(of: find.byType(IqDock), matching: find.text('Discover')),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('B5: the sheet closes from its close button and the scrim', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      Routes.withdraw,
      repository: WalletRepository(),
      overrides: walletOverrides(),
    );
    await _settle(tester);
    await _tap(tester, find.bySemanticsLabel('Close'));
    expect(find.byType(WithdrawSheet), findsNothing);
    expect(find.byType(WalletScreen), findsOneWidget);

    await _tap(tester, find.text('Withdraw'));
    await _settle(tester);
    await tester.tapAt(const Offset(195, 100));
    await tester.pumpAndSettle();
    expect(find.byType(WithdrawSheet), findsNothing);
    semantics.dispose();
  });

  testWidgets('B5: a drag on the grabber closes the sheet; a nudge does not', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.withdraw,
      repository: WalletRepository(),
      overrides: walletOverrides(),
    );
    await _settle(tester);
    final title = find
        .descendant(
          of: find.byType(WithdrawSheet),
          matching: find.text('Withdraw'),
        )
        .first;
    await tester.drag(title, const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(find.byType(WithdrawSheet), findsOneWidget);
    await tester.drag(title, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(WithdrawSheet), findsNothing);
  });

  testWidgets('B5: the amount follows the web rules', (tester) async {
    final haptics = recordHaptics(tester);
    final wallet = instantWallet();
    await pumpApp(
      tester,
      Routes.withdraw,
      repository: WalletRepository(),
      overrides: walletOverrides(wallet: wallet),
    );
    await _settle(tester);
    const help = 'Minimum ₦1,000 · available ₦12,500.00';
    expect(find.text(help), findsNothing);

    await _tap(tester, find.text('Withdraw').last);
    expect(find.text(help), findsOneWidget);
    expect(haptics, [_commit, _error]);

    await _type(tester, _amountField(), '999');
    expect(find.text(help), findsNothing);
    await _tap(tester, find.text('Withdraw').last);
    expect(find.text(help), findsOneWidget);
    expect(wallet.requests, isEmpty);

    await _type(tester, _amountField(), '12500.01');
    expect(find.text('₦12,500.01'), findsOneWidget);
    expect(find.text(help), findsOneWidget);
    expect(tester.widget<IqField>(_amountField()).state, IqFieldState.error);

    await _type(tester, _amountField(), '12500');
    expect(find.text(help), findsNothing);
    expect(find.text('Ready · bank saved'), findsOneWidget);
    await _tap(tester, find.text('Withdraw').last);
    expect(wallet.requests.single.amountKobo, 1250000);
    expect(find.text('₦0.00'), findsOneWidget);
  });

  testWidgets('B14: the failed ₦5,000.00, retried to another bank', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final haptics = recordHaptics(tester);
    final wallet = instantWallet();
    await pumpApp(
      tester,
      Routes.wallet,
      repository: WalletRepository(),
      overrides: walletOverrides(wallet: wallet),
    );
    await _tap(tester, find.text('failed'));
    expect(find.byType(WithdrawalFailedScreen), findsOneWidget);
    expect(
      find.text('Account name didn’t match. Nothing left your wallet.'),
      findsOneWidget,
    );
    expect(find.text('IQ-WD-240922-3C7Q'), findsOneWidget);
    expect(find.text('11 days ago, 2:05 pm'), findsOneWidget);
    expect(find.text('11 days ago, 4:40 pm'), findsOneWidget);
    expect(find.text('Failed at the bank'), findsOneWidget);
    expect(find.text('Failed'), findsNothing);

    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(WalletScreen), findsOneWidget);
    await _tap(tester, find.text('failed'));

    await _tap(tester, find.text('Check bank details'));
    expect(find.byType(SelectBankScreen), findsOneWidget);
    await _type(
      tester,
      find.byWidgetPredicate((w) => w is IqField && w.label == 'Search'),
      'kuda',
    );
    expect(find.text('Access Bank'), findsNothing);
    await _tap(tester, find.text('Kuda Bank'));
    await _settle(tester);

    Finder inSheet(String text) => find.descendant(
      of: find.byType(WithdrawSheet),
      matching: find.text(text),
    );
    expect(inSheet('₦5,000.00'), findsOneWidget);
    expect(inSheet('Kuda Bank'), findsOneWidget);
    expect(inSheet('Account number next'), findsOneWidget);

    await _type(
      tester,
      _accountField(),
      DemoWalletService.unverifiableAccountNumber,
    );
    expect(find.text(verifyHelp), findsOneWidget);
    expect(find.text('Fix the account number'), findsOneWidget);

    await _type(tester, _accountField(), '0123456789');
    expect(find.text(verifyHelp), findsNothing);
    expect(find.text('Verified: ADAEZE OKAFOR'), findsOneWidget);
    expect(find.text('Ready · bank verified'), findsOneWidget);

    await _tap(tester, find.text('Withdraw').last);
    expect(find.byType(WithdrawalPendingScreen), findsOneWidget);
    expect(find.text('to Kuda Bank ••6789'), findsOneWidget);
    expect(wallet.requests.single.account.bankName, 'Kuda Bank');
    expect(wallet.requests.single.amountKobo, 500000);
    expect(haptics, [_commit, _error, _success, _commit, _success]);
    semantics.dispose();
  });

  testWidgets(
    'B14: the pending ₦10,000.00 advances on the tracker and lands on Home',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        Routes.wallet,
        repository: WalletRepository(),
        overrides: walletOverrides(
          wallet: instantWallet(payoutStep: const Duration(seconds: 1)),
        ),
      );
      await _tap(tester, find.text('pending'));
      expect(find.byType(WithdrawalTrackerScreen), findsOneWidget);
      expect(find.text('IQ-WD-241003-9A2M'), findsOneWidget);
      expect(find.text('Today, 7:40 am'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Awaiting approval'), findsOneWidget);
      expect(find.text('Usually within a few hours'), findsOneWidget);
      IqTimelineRow row(String title) => tester.widget<IqTimelineRow>(
        find.widgetWithText(IqTimelineRow, title),
      );
      expect(row('Sent to your bank').state, IqTimelineRowState.upcoming);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Approved by iQLY'), findsOneWidget);
      expect(row('Sent to your bank').state, IqTimelineRowState.current);
      expect(find.text('Pending'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(row('Arrived').state, IqTimelineRowState.current);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(row('Arrived').state, IqTimelineRowState.done);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.byType(WithdrawalTrackerScreen), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Back'));
      await _settle(tester);
      expect(find.text('completed'), findsNWidgets(2));
      expect(_hero(tester).amount, '₦12,500');
      expect(_hero(tester).onHold, '₦0.00');
      expect(find.text('ON HOLD · 0 PENDING'), findsOneWidget);

      await _tap(
        tester,
        find.descendant(
          of: find.byType(IqDock),
          matching: find.text('Discover'),
        ),
      );
      expect(find.text('₦10,000.00 completed'), findsOneWidget);
      expect(find.text('Access Bank ••6789'), findsOneWidget);
      await _tap(tester, find.text('₦10,000.00 completed'));
      expect(find.byType(WithdrawalTrackerScreen), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      await _tap(tester, find.bySemanticsLabel('Back'));
      expect(find.byType(WalletScreen), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('B14: Home shows no payout row without a recent arrival', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.home,
      repository: WalletRepository(),
      overrides: walletOverrides(),
    );
    expect(find.textContaining('completed'), findsNothing);
  });

  testWidgets('B14: Share receipt hands the card to the share sheet', (
    tester,
  ) async {
    final share = DemoShareService();
    await pumpApp(
      tester,
      '/wallet/withdrawals/w3',
      repository: WalletRepository(),
      overrides: walletOverrides(share: share),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Share receipt'));
      for (var i = 0; i < 20 && share.shared.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(share.shared.single.name, 'iqly-receipt-IQ-WD-241003-9A2M.png');
    expect(share.shared.single.bytes, greaterThan(0));
  });

  testWidgets('B5: failed to load, Try again loads the wallet', (tester) async {
    final haptics = recordHaptics(tester);
    final repository = FailingWalletRepository();
    await pumpApp(
      tester,
      Routes.wallet,
      repository: repository,
      overrides: walletOverrides(),
    );
    expect(find.text('Couldn’t load. Check your connection.'), findsOneWidget);
    expect(find.byType(IqBalanceHero), findsNothing);
    expect(haptics, isEmpty);

    await _tap(tester, find.text('Try again'));
    await _settle(tester);
    expect(find.text('Couldn’t load. Check your connection.'), findsOneWidget);
    expect(haptics, [_error]);

    repository.fail = false;
    await _tap(tester, find.text('Try again'));
    await _settle(tester);
    expect(find.byType(IqBalanceHero), findsOneWidget);
    expect(find.text('Access Bank ••6789'), findsOneWidget);
    expect(repository.calls, 3);
  });

  testWidgets('B5: no activity yet', (tester) async {
    await pumpApp(
      tester,
      Routes.wallet,
      repository: EmptyWalletRepository(),
      overrides: walletOverrides(),
    );
    expect(find.text('No activity yet'), findsOneWidget);
    expect(find.text('Rewards and withdrawals land here.'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(_hero(tester).amount, '₦0');
  });

  testWidgets('every wallet target is at least 44 pt and labelled', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      Routes.wallet,
      repository: WalletRepository(),
      overrides: walletOverrides(),
    );
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await _tap(tester, find.text('Withdraw'));
    await _settle(tester);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  for (final (name, location, repository) in [
    ('pending', '/wallet/withdrawals/w4/pending', RequestedWalletRepository()),
    ('tracker', '/wallet/withdrawals/w3', WalletRepository()),
    ('failed', '/wallet/withdrawals/w1', WalletRepository()),
    ('Home after payout', Routes.home, PaidOutWalletRepository()),
  ]) {
    testWidgets('$name: 44 pt targets, all labelled', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        location,
        repository: repository,
        overrides: walletOverrides(),
      );
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }

  testWidgets('select bank: every row is a labelled 64 pt target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      Routes.selectBank,
      repository: WalletRepository(),
      overrides: walletOverrides(),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(
      tester.getSize(find.widgetWithText(IqListRow, 'Kuda Bank')).height,
      64,
    );
    semantics.dispose();
  });

  testWidgets('system back from the pending screen returns to the Wallet', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.withdraw,
      repository: WalletRepository(),
      overrides: walletOverrides(),
    );
    await _settle(tester);
    await _type(tester, _amountField(), '2000');
    await _tap(tester, find.text('Withdraw').last);
    expect(find.byType(WithdrawalPendingScreen), findsOneWidget);
    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await _settle(tester);
    expect(find.byType(WithdrawalPendingScreen), findsNothing);
    expect(find.byType(WalletScreen), findsOneWidget);
    expect(_hero(tester).amount, '₦10,500');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  });
}
