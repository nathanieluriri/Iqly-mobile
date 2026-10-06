import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/wallet/bank_account_sheet.dart';
import 'package:iqly_mobile/features/wallet/pin_sheet.dart';
import 'package:iqly_mobile/features/wallet/wallet_screen.dart';
import 'package:iqly_mobile/features/wallet/withdraw_sheet.dart';
import 'package:iqly_mobile/features/wallet/withdrawal_pending_screen.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_tracker_screen.dart';
import 'package:iqly_mobile/ui/pressable.dart';
import 'package:iqly_mobile/ui/wallet_card.dart';

import '../harness.dart';
import '../steps.dart';

Finder _labelled(String label) => find.byWidgetPredicate(
  (w) => w is IqPressable && w.semanticLabel == label,
  description: '"$label"',
);

/// A returning contributor opens the Wallet: the eye hides and shows the
/// balance, the balance tabs switch the card, then ₦5,000.00 goes out: the
/// withdraw sheet, To opens the Bank account sheet for another saved
/// account, the PIN confirms, the pending page, Done back to the Wallet,
/// and the withdrawal's tracker from its row.
void main() {
  film('wallet_withdraw', prefs: returning, (d) async {
    await onDiscover(d, hold: 1);

    await dockTab(d, 'Wallet');
    await d.waitFor(find.byType(IqWalletCard));
    await d.settle(on: find.byType(WalletScreen));
    await d.hold(2);

    await d.tap(_labelled('Hide balance'), label: 'eye-hide');
    await d.hold(1.4);
    await d.tap(_labelled('Show balance'), label: 'eye-show');
    await d.hold(1.2);
    await d.tap(find.text('On its way'));
    await d.hold(1.4);
    await d.tap(find.text('Earned'));
    await d.hold(1.6);
    await d.tap(find.text('Available'));
    await d.hold(1.2);

    await d.tap(find.text('Withdraw'), label: 'withdraw');
    await d.arrive(find.byType(WithdrawSheet), hold: 0.8);
    await d.type('5000');
    await d.hold(1);
    await d.tap(find.text('Access Bank ••6789 · ADAEZE OKAFOR'), label: 'to');
    await d.arrive(find.byType(BankAccountSheet), hold: 1.2);
    await d.tap(find.text('Guaranty Trust Bank ••4410'));
    await d.gone(find.byType(BankAccountSheet));
    await d.settle(on: find.byType(WithdrawSheet));
    await d.hold(1.2);
    await d.tap(
      find.descendant(
        of: find.byType(WithdrawSheet),
        matching: button('Withdraw'),
      ),
      label: 'withdraw-5000',
    );

    await d.arrive(find.byType(PinSheet), hold: 0.8);
    await d.type('1234', cps: 6);
    await d.hold(0.6);
    await d.tap(button('Confirm withdrawal'), label: 'confirm-withdrawal');

    await d.arrive(find.byType(WithdrawalPendingScreen), hold: 2.5);
    await d.tap(button('Done'), label: 'done');
    await d.gone(find.byType(WithdrawalPendingScreen));
    await d.settle(on: find.byType(WalletScreen));
    await d.hold(2);

    final row = find.text('Just now');
    await d.reveal(row, listIn(find.byType(WalletScreen)));
    await d.hold(0.6);
    await d.tap(row, label: 'new-withdrawal');
    await d.arrive(find.byType(WithdrawalTrackerScreen), hold: 2.5);
    await d.back();

    await d.gone(find.byType(WithdrawalTrackerScreen));
    await d.settle(on: find.byType(WalletScreen));
    await d.hold(2);
  });
}
