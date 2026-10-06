import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/wallet/activity_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_screen.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_failed_screen.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_tracker_screen.dart';
import 'package:iqly_mobile/ui/wallet_card.dart';

import '../harness.dart';
import '../steps.dart';

/// A returning contributor checks where their money went: the Wallet's See
/// all opens Activity, its Rewards and Withdrawals tabs, the arrived payout's
/// tracker, the failed one's page, then Filter down to Reversed and its
/// page, and back out to the Wallet.
void main() {
  film('wallet_activity', prefs: returning, (d) async {
    await onDiscover(d, hold: 1);

    await dockTab(d, 'Wallet');
    await d.waitFor(find.byType(IqWalletCard));
    await d.settle(on: find.byType(WalletScreen));
    await d.hold(1.5);
    final seeAll = find.text('See all');
    await d.reveal(seeAll, listIn(find.byType(WalletScreen)));
    await d.hold(0.5);
    await d.tap(seeAll, label: 'see-all');

    await d.arrive(find.byType(ActivityScreen), hold: 1.8);
    await d.tap(find.text('Rewards'));
    await d.hold(1.6);
    await d.tap(find.text('Withdrawals').first, label: 'withdrawals-tab');
    await d.hold(1.6);

    await d.tap(find.text('Completed'), label: 'arrived-row');
    await d.arrive(find.byType(WithdrawalTrackerScreen), hold: 2.2);
    await d.back();
    await d.arrive(find.byType(ActivityScreen), hold: 0.8);

    await d.tap(
      find.text('Failed · nothing left your wallet'),
      label: 'failed-row',
    );
    await d.arrive(find.byType(WithdrawalFailedScreen), hold: 2.2);
    await d.back();
    await d.arrive(find.byType(ActivityScreen), hold: 0.8);

    await d.tap(find.text('Filter'), label: 'filter');
    await d.waitFor(find.text('Reversed'));
    await d.settle(on: find.text('Reversed'));
    await d.hold(1);
    await d.tap(find.text('Reversed'));
    await d.hold(0.8);
    await d.tap(find.textContaining('Show '), label: 'show-results');
    await d.waitFor(find.text('1 results'));
    await d.settle(on: find.byType(ActivityScreen));
    await d.hold(1.5);

    await d.tap(
      find.text('Reversed · back in your wallet'),
      label: 'reversed-row',
    );
    await d.arrive(find.byType(WithdrawalFailedScreen), hold: 2.2);
    await d.back();
    await d.arrive(find.byType(ActivityScreen), hold: 1);
    await d.back();

    await d.arrive(find.byType(WalletScreen), hold: 2);
  });
}
