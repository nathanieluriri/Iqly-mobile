import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/notifications/notification_screen.dart';
import 'package:iqly_mobile/features/notifications/notifications_screen.dart';
import 'package:iqly_mobile/features/outcomes/result_screen.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_tracker_screen.dart';
import 'package:iqly_mobile/ui/icon.dart';

import '../harness.dart';
import '../steps.dart';

Finder _row(String text) => find.text(text, findRichText: true);

/// A returning contributor catches up from the bell on Discover: the payout
/// notification's page and the withdrawal it names, the result
/// notification's page and the result, the deadline's page and the brief,
/// each Back returning to its opener, and back to Discover.
void main() {
  film('notifications', prefs: returning, (d) async {
    await onDiscover(d, hold: 1.2);

    await d.tap(
      find.byWidgetPredicate((w) => w is IqIcon && w.icon == IqIcons.bell),
      label: 'bell',
    );
    await d.arrive(find.byType(NotificationsScreen), hold: 1.8);

    await d.tap(_row('₦40,000.00 paid out'), label: 'payout');
    await d.arrive(find.byType(NotificationScreen), hold: 1.5);
    await d.tap(button('Open wallet'), label: 'open-wallet');
    await d.arrive(find.byType(WithdrawalTrackerScreen), hold: 1.8);
    await d.back();
    await d.arrive(find.byType(NotificationScreen), hold: 0.6);
    await d.back();
    await d.arrive(find.byType(NotificationsScreen), hold: 1);

    await d.tap(_row('You won ₦12,500.00'), label: 'result');
    await d.arrive(find.byType(NotificationScreen), hold: 1.5);
    await d.tap(button('See the result'), label: 'see-the-result');
    await d.arrive(find.byType(WinnerView), hold: 2);
    await d.back();
    await d.arrive(find.byType(NotificationScreen), hold: 0.6);
    await d.back();
    await d.arrive(find.byType(NotificationsScreen), hold: 1);

    await d.tap(_row('Kudi Box closes tomorrow'), label: 'deadline');
    await d.arrive(find.byType(NotificationScreen), hold: 1.5);
    await d.tap(button('See the brief'), label: 'see-the-brief');
    await d.arrive(find.byType(BriefDetailScreen), hold: 1.8);
    await d.back();
    await d.arrive(find.byType(NotificationScreen), hold: 0.6);
    await d.back();
    await d.arrive(find.byType(NotificationsScreen), hold: 1.2);
    await d.back();

    await d.arrive(find.byType(HomeScreen), hold: 1.5);
  });
}
