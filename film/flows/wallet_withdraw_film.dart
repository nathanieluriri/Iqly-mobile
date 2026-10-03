import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_screen.dart';
import 'package:iqly_mobile/features/wallet/withdraw_sheet.dart';
import 'package:iqly_mobile/features/wallet/withdrawal_pending_screen.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_tracker_screen.dart';
import 'package:iqly_mobile/ui/activity_row.dart';
import 'package:iqly_mobile/ui/balance_hero.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/dock.dart';

import '../harness.dart';

const _returning = <String, Object>{
  'session.signedIn': true,
  'session.onboardingDone': true,
  'session.firstTipSeen': true,
};

/// A returning contributor withdraws ₦5,000 to the saved bank, comes back
/// to the Wallet as the figures roll, and follows the pending ₦10,000.00
/// on its tracker.
void main() {
  film('wallet_withdraw', prefs: _returning, (d) async {
    await d.waitFor(find.byType(HomeScreen));
    await d.waitFor(find.text('Closing soon'));
    await d.settle(on: find.byType(HomeScreen));
    await d.hold(1.5);

    await d.tap(
      find.descendant(of: find.byType(IqDock), matching: find.text('Wallet')),
      label: 'wallet-tab',
    );
    await d.waitFor(find.byType(IqBalanceHero));
    await d.settle(on: find.byType(WalletScreen));
    await d.hold(2);

    await d.tap(
      find.descendant(
        of: find.byType(IqBalanceHero),
        matching: find.text('Withdraw'),
      ),
      label: 'withdraw',
    );
    await d.arrive(find.byType(WithdrawSheet), hold: 0.6);
    await d.type('5000');
    await d.waitFor(find.text('Ready · bank saved'));
    await d.hold(1.4);
    await d.tap(
      find.descendant(
        of: find.byType(WithdrawSheet),
        matching: find.widgetWithText(IqButton, 'Withdraw'),
      ),
      label: 'withdraw-5000',
    );

    await d.arrive(find.byType(WithdrawalPendingScreen), hold: 2.5);
    await d.tap(find.text('Back to wallet'));
    await d.gone(find.byType(WithdrawalPendingScreen));
    await d.settle(on: find.byType(WalletScreen));
    await d.waitFor(find.text('Just now'));
    await d.hold(2.2);

    await d.tap(
      find.byWidgetPredicate(
        (w) =>
            w is IqActivityRowWithdrawal &&
            w.amount == '₦10,000.00' &&
            w.status == 'pending',
      ),
      label: 'pending-10000',
    );
    await d.arrive(find.byType(WithdrawalTrackerScreen), hold: 0.5);
    await d.waitFor(find.text('Completed'));
    await d.hold(2);
    await d.back();

    await d.gone(find.byType(WithdrawalTrackerScreen));
    await d.settle(on: find.byType(WalletScreen));
    await d.hold(2);
  });
}
