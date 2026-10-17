import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/notifications/notification_screen.dart';
import 'package:iqly_mobile/features/notifications/notifications_screen.dart';
import 'package:iqly_mobile/features/outcomes/outcomes_routes.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/leaderboard_row.dart';
import 'package:iqly_mobile/ui/notification.dart';
import 'package:iqly_mobile/ui/pressable.dart';

import '../data/live/live_data_fixtures.dart' as data;
import '../golden/screens/app_harness.dart';
import '../support/live_api.dart';
import '../support/live_app.dart';

/// [hours] before the Figma 9:41, as the API writes it.
String _ago(int hours) =>
    figmaNow.subtract(Duration(hours: hours)).toUtc().toIso8601String();

Map<String, Object?> _row(
  String id,
  String type,
  int hoursAgo, {
  String title = '',
  String body = '',
  Map<String, Object?> refs = const {},
  int? amountKobo,
  Map<String, Object?>? brief,
  Map<String, Object?>? withdrawal,
}) => {
  'id': id,
  'type': type,
  'createdAt': _ago(hoursAgo),
  'readAt': null,
  'title': title,
  'body': body,
  'refs': {
    'challengeId': null,
    'submissionId': null,
    'withdrawalId': null,
    'ledgerId': null,
    ...refs,
  },
  'amountKobo': amountKobo,
  'brief': brief,
  'withdrawal': withdrawal,
};

Map<String, Object?> _withdrawal(String status, int amountKobo) => {
  'id': 'w_live',
  'amountKobo': amountKobo,
  'status': status,
  'bankName': 'Access Bank',
  'accountLast4': '6789',
  'reference': 'IQ-WD-261003-AB12',
};

/// One row of each type, none of them in the records the app has loaded.
final _feed = [
  _row(
    'n_won',
    'payout_confirmed',
    1,
    title: 'You won ₦12,500.00',
    refs: {
      'challengeId': 'c_live',
      'submissionId': 's_live',
      'ledgerId': 't_live',
    },
    amountKobo: 1250000,
    brief: {
      'id': 'c_live',
      'title': 'Sunday is data day',
      'businessName': null,
      'logoUrl': null,
    },
  ),
  _row(
    'n_requested',
    'withdrawal_requested',
    2,
    refs: {'withdrawalId': 'w_live'},
    amountKobo: 1000000,
    withdrawal: _withdrawal('pending', 1000000),
  ),
  _row(
    'n_paid',
    'payout_completed',
    26,
    refs: {'withdrawalId': 'w_live'},
    amountKobo: 1000000,
    withdrawal: _withdrawal('completed', 1000000),
  ),
  _row(
    'n_failed',
    'payout_failed',
    50,
    refs: {'withdrawalId': 'w_live'},
    amountKobo: 500000,
    withdrawal: _withdrawal('failed', 500000),
  ),
  _row(
    'n_results',
    'review_ready',
    74,
    title: 'Results are in for “Sunday is data day”',
    body:
        'A business kept private has finished reviewing submissions and '
        'winners have been published.',
    refs: {'challengeId': 'c_live'},
  ),
  _row(
    'n_extended',
    'deadline_extended',
    98,
    title: 'More time to submit',
    body:
        'Sunline extended “A tagline for a solar kiosk network”. The new '
        'deadline is Saturday 10 October at 6:00 pm.',
    refs: {'challengeId': 'c5'},
  ),
  _row(
    'n_odd',
    'referral_joined',
    122,
    title: 'Tobi joined iQLY',
    body: 'Your invite code worked.',
  ),
];

void main() {
  testWidgets('the live feed words each row from what it embeds, keeps the '
      'API\'s words for the rest and drops none; the bell reads unseen and '
      'clears once the feed is seen', (tester) async {
    final api = accountApi({
      'GET /notifications': (_) =>
          answer({'items': _feed, 'nextCursor': null, 'unseen': 2}),
    });
    final (container, _) = await pumpLive(tester, Routes.home, api);
    expect(container.read(unreadNotificationsProvider).value, 2);

    final bell = find.byWidgetPredicate(
      (w) => w is IqPressable && w.semanticLabel == 'Notifications',
    );
    await tester.tap(bell.first);
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);
    final rows = tester
        .widgetList<IqNotification>(find.byType(IqNotification))
        .map((n) => (n.kind, n.headline, n.detail))
        .toList();
    expect(rows, [
      (IqNotificationKind.result, 'You won ₦12,500.00', 'Sunday is data day'),
      (
        IqNotificationKind.payout,
        '₦10,000.00 requested',
        'Access Bank ••6789 · pending',
      ),
      (
        IqNotificationKind.payout,
        '₦10,000.00 paid out',
        'Sent to Access Bank ••6789 · completed',
      ),
      (
        IqNotificationKind.payout,
        '₦5,000.00 never left your wallet',
        'Withdrawal to Access Bank ••6789 failed',
      ),
      (
        IqNotificationKind.result,
        'Results are in for “Sunday is data day”',
        'A business kept private has finished reviewing submissions and '
            'winners have been published.',
      ),
      (
        IqNotificationKind.deadline,
        'More time to submit',
        'Sunline extended “A tagline for a solar kiosk network”. The new '
            'deadline is Saturday 10 October at 6:00 pm.',
      ),
      (
        IqNotificationKind.deadline,
        'Tobi joined iQLY',
        'Your invite code worked.',
      ),
    ]);
    expect(container.read(unreadNotificationsProvider).value, 0);
    final store = container.read(accountLinkProvider)!.store;
    final seen = (await store.outbox('u_1')).single;
    expect(seen.kind, AccountWrite.seen.kind);
    expect(seen.payload, {'until': _ago(1)});
  });

  testWidgets('a live win opens its Notification page worded from the row, '
      'and reads as read', (tester) async {
    final api = accountApi({
      'GET /notifications': (_) =>
          answer({'items': _feed, 'nextCursor': null, 'unseen': 0}),
    });
    final (container, _) = await pumpLive(tester, Routes.notifications, api);
    await tester.tap(find.text('You won ₦12,500.00', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationScreen), findsOneWidget);
    expect(
      find.text(
        'A business kept private picked your answer to “Sunday is data '
        'day”. ₦12,500.00 is in your wallet now.',
      ),
      findsOneWidget,
    );
    expect(find.text('See the result'), findsOneWidget);
    final store = container.read(accountLinkProvider)!.store;
    final marks = {
      for (final item in await store.outbox('u_1')) item.kind: item.payload,
    };
    expect(marks[AccountWrite.read.kind], {
      'ids': ['n_won'],
    });
  });

  testWidgets('the live leaderboard has no entry titles but your own, so the '
      'other rows drop the line', (tester) async {
    Map<String, Object?> leader(int rank, String name, [int? kobo]) => {
      'rank': rank,
      'name': name,
      'amountKobo': kobo,
      'you': false,
    };
    final api = accountApi({
      'GET /submissions/mine': (_) => answer(
        data.page([
          data.submissionJson({
            'id': 's2',
            'challengeId': 'c3',
            'brief': {
              ...data.submissionJson()['brief']! as Map<String, Object?>,
              'id': 'c3',
              'title': 'Sunday is data day',
            },
          }),
        ]),
      ),
      'GET /submissions/s2/outcome': (_) => answer({
        'submissionId': 's2',
        'challengeId': 'c3',
        'link': 'https://iqly.net/challenges/c3',
        'resultsPublishedAt': _ago(48),
        'entries': 48,
        'rank': 5,
        'leaders': [
          leader(1, 'Chinedu A.', 17500000),
          leader(2, 'Tunde F.', 10000000),
          leader(3, 'Anonymous', 6250000),
          leader(4, 'Ngozi E.', 5000000),
          {...leader(5, 'Ada O.', 1250000), 'you': true},
          leader(6, 'Bola A.'),
          leader(7, 'Amaka O.'),
        ],
        'note': null,
      }),
    });
    await pumpLive(
      tester,
      leaderboardPath('s2'),
      api,
      repository: LiveRepository(
        api: api.client,
        store: liveStore(),
        mode: allLive,
        demo: ScriptedRepository(),
        userId: 'u_1',
        clock: () => figmaNow,
      ),
    );
    final rows = tester
        .widgetList<IqLeaderboardRow>(find.byType(IqLeaderboardRow))
        .map((r) => (r.rank, r.name, r.showEntry, r.state))
        .toList();
    expect(rows, [
      ('4', 'Ngozi E.', false, IqLeaderboardRowState.standard),
      ('5', 'You', true, IqLeaderboardRowState.you),
      ('6', 'Bola A.', false, IqLeaderboardRowState.standard),
      ('7', 'Amaka O.', false, IqLeaderboardRowState.standard),
    ]);
    expect(find.text('Sunday is data day'), findsWidgets);
  });
}
