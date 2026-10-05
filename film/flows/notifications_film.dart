import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/notifications/notification_screen.dart';
import 'package:iqly_mobile/features/notifications/notifications_screen.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/notification.dart';

import '../harness.dart';
import '../steps.dart';

Finder _row(String headline) => find.byWidgetPredicate(
  (w) => w is IqNotification && w.headline == headline,
  description: 'the "$headline" notification',
);

/// A returning contributor signs in, opens the bell on Discover, reads the
/// feed, opens the Sunline reminder (its Notification page, then its brief)
/// and comes back to the feed, where the row's unread dot has gone, then
/// back to Discover.
void main() {
  film('notifications', (d) async {
    await signIn(d);

    await d.tap(
      find.byWidgetPredicate((w) => w is IqIcon && w.icon == IqIcons.bell),
      label: 'bell',
    );
    await d.arrive(find.byType(NotificationsScreen), hold: 0);
    await d.waitFor(_row('Closes in 7h'));
    await d.hold(1.4);
    await d.tap(_row('Closes in 7h'), label: 'closes-in-7h');

    await d.arrive(find.byType(NotificationScreen), hold: 1.2);
    await d.tap(find.text('See the brief'));
    await d.arrive(find.byType(BriefDetailScreen), hold: 1.2);
    await d.back();
    await d.arrive(find.byType(NotificationScreen), hold: 0.6);
    await d.back();

    await d.arrive(find.byType(NotificationsScreen), hold: 1.2);
    expect(
      d.tester.widget<IqNotification>(_row('Closes in 7h')).unread,
      isFalse,
    );
    await d.back();

    await d.arrive(find.byType(HomeScreen), hold: 1.5);
  });
}
