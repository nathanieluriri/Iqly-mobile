import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/notifications/notifications_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_screen.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_failed_screen.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_tracker_screen.dart';
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
      ('Closes in 6h', '1h', true),
      ('₦10,000.00 requested', '2h', true),
      ('Closes in 1 day', '5h', true),
      ('You won ₦12,500.00', '2d', false),
      ('₦40,000.00 paid out', '10d', false),
      ('₦5,000.00 payout failed', '11d', false),
    ]);
    expect(
      find.text('Sunline · A tagline for a solar kiosk network'),
      findsOneWidget,
    );
    expect(find.text('Access Bank ••6789 · pending'), findsOneWidget);
    expect(find.text('Sent to Access Bank ••6789 · completed'), findsOneWidget);
    expect(
      find.text('Access Bank ••6789 · back in your balance'),
      findsOneWidget,
    );
    expect(container.read(unreadNotificationsProvider).value, 0);

    await _tap(tester, find.text('Closes in 6h'));
    expect(find.byType(BriefDetailScreen), findsOneWidget);
    expect(find.text('A tagline for a solar kiosk network'), findsOneWidget);
    await _back(tester);
    expect(_row(tester, 'Closes in 6h').unread, isFalse);
    expect(_row(tester, 'Closes in 1 day').unread, isTrue);

    await _tap(tester, find.text('₦10,000.00 requested'));
    expect(find.byType(WithdrawalTrackerScreen), findsOneWidget);
    await _back(tester);
    expect(_row(tester, '₦10,000.00 requested').unread, isFalse);

    await _tap(tester, find.text('Closes in 1 day'));
    expect(find.byType(BriefDetailScreen), findsOneWidget);
    expect(
      find.text('Redesign the first five minutes of our savings app'),
      findsOneWidget,
    );
    await _back(tester);

    await _tap(tester, find.text('You won ₦12,500.00'));
    expect(find.byType(SubmissionDetailScreen), findsOneWidget);
    expect(find.text('Sunday is data day'), findsOneWidget);
    await _back(tester);

    await _tap(tester, find.text('₦5,000.00 payout failed'));
    expect(find.byType(WithdrawalFailedScreen), findsOneWidget);
    await _back(tester);

    await _tap(tester, find.text('₦40,000.00 paid out'));
    expect(find.byType(NotificationsScreen), findsNothing);
    expect(find.byType(WalletScreen), findsOneWidget);

    await _tap(tester, _labelled('Notifications'));
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(
      tester
          .widgetList<IqNotification>(find.byType(IqNotification))
          .where((n) => n.unread)
          .length,
      0,
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
