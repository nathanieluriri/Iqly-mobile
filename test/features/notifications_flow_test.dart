import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/notifications/notification_screen.dart';
import 'package:iqly_mobile/features/notifications/notifications_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_screen.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_failed_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/notification.dart';
import 'package:iqly_mobile/ui/pressable.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/polls_notifications_help_harness.dart';
import '../golden/screens/wallet_harness.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _labelled(String label) =>
    find.byWidgetPredicate((w) => w is IqPressable && w.semanticLabel == label);

IqNotification _row(WidgetTester tester, String headline) =>
    tester.widget<IqNotification>(
      find.byWidgetPredicate(
        (w) => w is IqNotification && w.headline == headline,
      ),
    );

Future<void> _back(WidgetTester tester) async {
  await _tap(tester, _labelled('Back').last);
  expect(find.byType(NotificationsScreen), findsOneWidget);
}

void main() {
  testWidgets('B6: the bell, each row to its screen, the bell clears', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      Routes.home,
      overrides: [...laneOverrides(), ...walletOverrides()],
    );
    expect(container.read(unreadNotificationsProvider).value, 3);

    await _tap(tester, _labelled('Notifications'));
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);
    final headlines = tester
        .widgetList<IqNotification>(find.byType(IqNotification))
        .map((n) => (n.headline, n.when, n.unread))
        .toList();
    expect(headlines, [
      ('Closes in 7h', '1h', true),
      ('₦1,500.00 added to your wallet', '2h', true),
      ('Kudi Box closes tomorrow', '5h', true),
      ('You won ₦12,500.00', '2d', false),
      ('₦40,000.00 paid out', '10d', false),
      ('₦5,000.00 never left your wallet', '11d', false),
    ]);
    expect(container.read(unreadNotificationsProvider).value, 0);

    await _tap(tester, find.text('Closes in 7h'));
    expect(find.byType(NotificationScreen), findsOneWidget);
    await _tap(tester, find.text('See the brief'));
    expect(find.byType(BriefDetailScreen), findsOneWidget);
    await _tap(tester, _labelled('Back').last);
    await _back(tester);
    expect(_row(tester, 'Closes in 7h').unread, isFalse);
    expect(_row(tester, 'Kudi Box closes tomorrow').unread, isTrue);

    await _tap(tester, find.text('You won ₦12,500.00'));
    await _tap(tester, find.text('See the result'));
    expect(find.byType(NotificationScreen), findsNothing);
    await _tap(tester, _labelled('Back').last);
    await _back(tester);

    await _tap(tester, find.text('₦5,000.00 never left your wallet'));
    await _tap(tester, find.text('See what happened'));
    expect(find.byType(WithdrawalFailedScreen), findsOneWidget);
    await _tap(tester, _labelled('Back').last);
    await _back(tester);

    await _tap(tester, find.text('₦1,500.00 added to your wallet'));
    await _tap(tester, find.text('Open wallet'));
    expect(find.byType(WalletScreen), findsOneWidget);

    await _tap(tester, _labelled('Notifications'));
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(
      tester
          .widgetList<IqNotification>(find.byType(IqNotification))
          .where((n) => n.unread)
          .length,
      1,
    );
  });

  testWidgets('B6 empty: Browse briefs goes to Discover', (tester) async {
    await pumpApp(
      tester,
      Routes.notifications,
      overrides: laneOverrides(notifications: EmptyNotificationsService()),
    );
    expect(find.text('Nothing yet'), findsOneWidget);
    expect(
      find.text('Deadlines, results and payouts land here.'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Browse briefs'));
    expect(find.byType(NotificationsScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('B6 failed: Try again loads the feed', (tester) async {
    final notifications = FailingNotificationsService();
    await pumpApp(
      tester,
      Routes.notifications,
      overrides: laneOverrides(notifications: notifications),
    );
    expect(find.text('Couldn’t load. Check your connection.'), findsOneWidget);
    notifications.fail = false;
    await _tap(tester, find.text('Try again'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(notifications.calls, 2);
    expect(find.text('Nothing yet'), findsOneWidget);
  });

  testWidgets('B6: back returns to the tab that rang', (tester) async {
    await pumpApp(
      tester,
      Routes.wallet,
      overrides: [...laneOverrides(), ...walletOverrides()],
    );
    await _tap(tester, _labelled('Notifications'));
    expect(find.byType(NotificationsScreen), findsOneWidget);
    await _tap(tester, _labelled('Back'));
    expect(find.byType(NotificationsScreen), findsNothing);
    expect(find.byType(WalletScreen), findsOneWidget);
  });
}
