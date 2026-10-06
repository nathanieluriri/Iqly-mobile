import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/referrals/referral_history_screen.dart';
import 'package:iqly_mobile/features/referrals/referrals_screen.dart';
import 'package:iqly_mobile/ui/gift_button.dart';

import '../harness.dart';
import '../steps.dart';

/// A returning contributor opens the app and taps the gift on Discover:
/// Referrals, Copy for the code, Invite friends and its share sheet, the
/// Referral history, and back to Discover.
void main() {
  film('referrals', prefs: returning, (d) async {
    await onDiscover(d, hold: 2);

    await d.tap(find.byType(IqGiftButton), label: 'gift');
    await d.arrive(find.byType(ReferralsScreen), hold: 1.8);
    await d.tap(find.text('Copy'), label: 'copy');
    await d.waitFor(find.text('Copied'));
    await d.hold(1.5);
    await d.tap(button('Invite friends'), label: 'invite-friends');
    await d.waitFor(find.text('Copy link'));
    await d.settle(on: find.text('Copy link'));
    await d.hold(2);
    await closeSheet(d);
    await d.gone(find.text('Copy link'));
    await d.settle(on: find.byType(ReferralsScreen));
    await d.hold(0.8);
    await d.tap(button('Referral history'), label: 'referral-history');
    await d.arrive(find.byType(ReferralHistoryScreen), hold: 2);
    await d.back();
    await d.arrive(find.byType(ReferralsScreen), hold: 1);
    await d.back();

    await d.arrive(find.byType(HomeScreen), hold: 2);
  });
}
