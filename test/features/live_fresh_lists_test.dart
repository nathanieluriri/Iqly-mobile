import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/notifications/notifications_state.dart';
import 'package:iqly_mobile/features/outcomes/result_screen.dart';
import 'package:iqly_mobile/features/profile/account_sync.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/features/submissions/submissions_state.dart';
import 'package:iqly_mobile/features/wallet/wallet_routes.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_tracker_screen.dart';
import 'package:iqly_mobile/router.dart';

import '../data/live/live_data_fixtures.dart' as data;
import '../support/live_api.dart' show meJson, profileJson;
import '../support/live_launch.dart';

const _failed = 'Couldn’t load. Check your connection.';

/// The API for Ada as a test scripts it: [routes] answer, anything else is
/// an empty page; [offline] answers nothing; every route asked is kept.
class _Api {
  _Api(this.routes);

  final Map<String, Object? Function()> routes;
  final asked = <String>[];
  final bodies = <String, List<Object?>>{};
  bool offline = false;

  Future<http.Response> answer(http.Request r) async {
    final route = '${r.method} ${r.url.path}';
    asked.add(route);
    if (r.body.isNotEmpty) (bodies[route] ??= []).add(jsonDecode(r.body));
    if (offline) throw http.ClientException('offline', r.url);
    final body = routes[route]?.call() ?? data.page([]);
    return http.Response.bytes(
      utf8.encode(jsonEncode({'success': true, 'data': body})),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  int count(String route) => asked.where((a) => a == route).length;

  ApiClient get client => ApiClient(
    tokens: MemoryTokenStore('t'),
    baseUrl: 'https://api.test',
    client: MockClient(answer),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

final _pending = data.submissionJson({
  'status': 'pending',
  'result': 'under_review',
  'award': null,
});

Map<String, Object?> _outcome() => {
  'submissionId': 's_1',
  'challengeId': 'c_9',
  'link': 'https://iqly.net/challenges/c_9',
  'resultsPublishedAt': '2026-10-17T09:00:00.000Z',
  'entries': 40,
  'rank': 1,
  'leaders': [
    {'rank': 1, 'name': 'Ada O.', 'amountKobo': 1250000, 'you': true},
  ],
  'note': null,
};

void main() {
  group('My submissions and results', () {
    testWidgets('a win published after the list loaded: the result opened '
        'by link reads the entry by id and shows the win, and the tab '
        'shown again reads the list again', (tester) async {
      var published = false;
      final api = _Api({
        'GET /me': meJson,
        'GET /profiles/contributors/me': profileJson,
        'GET /submissions/mine': () =>
            data.page([published ? data.submissionJson() : _pending]),
        'GET /submissions/s_1': () =>
            published ? data.submissionJson() : _pending,
        'GET /submissions/s_1/outcome': _outcome,
      });
      final (c, router) = await pumpLiveLaunch(
        tester,
        Routes.submissions,
        api: api.client,
      );
      await _settle(tester);
      expect(
        c.read(mySubmissionsProvider).value!.items.single.underReview,
        isTrue,
      );

      published = true;
      router.go(resultPath('s_1'));
      await _settle(tester);
      expect(find.byType(WinnerView), findsOneWidget);
      expect(api.count('GET /submissions/s_1'), greaterThan(0));

      final lists = api.count('GET /submissions/mine');
      router.go(Routes.submissions);
      await _settle(tester);
      expect(api.count('GET /submissions/mine'), greaterThan(lists));
      expect(
        c.read(mySubmissionsProvider).value!.items.single.underReview,
        isFalse,
      );
    });

    testWidgets('a result the API cannot give fails with Try again, which '
        'loads it once the API answers', (tester) async {
      final api = _Api({
        'GET /me': meJson,
        'GET /profiles/contributors/me': profileJson,
        'GET /submissions/mine': () => data.page([data.submissionJson()]),
        'GET /submissions/s_1': data.submissionJson,
        'GET /submissions/s_1/outcome': _outcome,
      })..offline = true;
      await pumpLiveLaunch(tester, resultPath('s_1'), api: api.client);
      await _settle(tester);
      await tester.pump(const Duration(seconds: 20));
      await _settle(tester);
      expect(find.text(_failed), findsOneWidget);

      api.offline = false;
      await tester.tap(find.text('Try again'));
      await _settle(tester);
      expect(find.byType(WinnerView), findsOneWidget);
    });

    testWidgets('a push reads My submissions and the feed again', (
      tester,
    ) async {
      final api = _Api({
        'GET /me': meJson,
        'GET /profiles/contributors/me': profileJson,
        'GET /submissions/mine': () => data.page([_pending]),
        'GET /notifications': () => {
          'items': <Object>[],
          'nextCursor': null,
          'unseen': 0,
        },
      });
      final (c, _) = await pumpLiveLaunch(
        tester,
        Routes.submissions,
        api: api.client,
      );
      await _settle(tester);
      await c.read(notificationsProvider.future);
      final lists = api.count('GET /submissions/mine');
      final feeds = api.count('GET /notifications');
      c.read(
        Provider(
          (ref) =>
              () => readAgainOnPush(ref),
        ),
      )();
      await _settle(tester);
      expect(api.count('GET /submissions/mine'), greaterThan(lists));
      expect(api.count('GET /notifications'), greaterThan(feeds));
    });
  });

  group('the notifications feed', () {
    Map<String, Object?> row(String id, DateTime at, String title) => {
      'id': id,
      'type': 'payout_completed',
      'createdAt': at.toIso8601String(),
      'readAt': null,
      'title': title,
      'body': 'Sent to Access Bank ••6789.',
      'refs': {
        'challengeId': null,
        'submissionId': null,
        'withdrawalId': 'w_1',
        'ledgerId': null,
      },
      'amountKobo': 1000000,
      'brief': null,
      'withdrawal': null,
    };

    testWidgets('a visit reads the feed again and marks seen up to the newest '
        'row it read', (tester) async {
      final rows = [
        row('n_1', DateTime.utc(2026, 10, 17, 7), 'Results are out'),
      ];
      final api = _Api({
        'GET /me': meJson,
        'GET /profiles/contributors/me': profileJson,
        'GET /notifications': () => {
          'items': [...rows.reversed],
          'nextCursor': null,
          'unseen': 0,
        },
        'POST /notifications/seen': () => {'unseen': 0},
      });
      final (c, router) = await pumpLiveLaunch(
        tester,
        Routes.notifications,
        api: api.client,
      );
      startAccountSync(c);
      await _settle(tester);
      router.go(Routes.home);
      await _settle(tester);

      rows.add(
        row('n_2', DateTime.utc(2026, 10, 17, 9, 30), '₦10,000.00 paid out'),
      );
      router.go(Routes.notifications);
      await _settle(tester);
      await tester.pump(const Duration(seconds: 3));
      await _settle(tester);
      expect(find.text('₦10,000.00 paid out'), findsOneWidget);
      final marks = [
        for (final body in api.bodies['POST /notifications/seen'] ?? [])
          (body! as Map)['until'],
      ];
      expect(marks.last, '2026-10-17T09:30:00.000Z');
      expect(c.read(notificationsProvider).value, hasLength(2));
    });
  });

  group('a withdrawal opened by link', () {
    Map<String, Object? Function()> wallet({bool listsIt = false}) => {
      'GET /me': meJson,
      'GET /profiles/contributors/me': profileJson,
      'GET /wallet': data.walletJson,
      'GET /wallet/withdrawals': () => data.page([
        if (listsIt) data.withdrawalJson({'id': 'w_2'}),
      ]),
      'GET /wallet/withdrawals/w_2': () => data.withdrawalJson({'id': 'w_2'}),
      'GET /wallet/bank-account': data.bankAccountJson,
      'GET /banks': () => data.banksJson,
    };

    testWidgets('one the wallet does not hold is read by id', (tester) async {
      final api = _Api(wallet());
      await pumpLiveLaunch(tester, withdrawalPath('w_2'), api: api.client);
      await _settle(tester);
      expect(find.byType(WithdrawalTrackerScreen), findsOneWidget);
      expect(api.count('GET /wallet/withdrawals/w_2'), greaterThan(0));
    });

    testWidgets('withdrawals paused: the failed state with Try again, and '
        'nothing asked', (tester) async {
      final api = _Api(wallet(listsIt: true));
      await pumpLiveLaunch(
        tester,
        withdrawalPath('w_2'),
        api: api.client,
        mode: Backend.of({
          for (final f in LiveFeature.values)
            if (f != LiveFeature.withdrawals) f,
        }),
      );
      await _settle(tester);
      expect(find.text(_failed), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(api.count('GET /wallet/withdrawals/w_2'), 0);
    });

    testWidgets('a wallet that fails to load: the failed state, then the '
        'withdrawal once Try again is answered', (tester) async {
      final api = _Api(wallet())..offline = true;
      await pumpLiveLaunch(tester, withdrawalPath('w_2'), api: api.client);
      await _settle(tester);
      await tester.pump(const Duration(seconds: 20));
      await _settle(tester);
      expect(find.text(_failed), findsOneWidget);

      api.offline = false;
      await tester.tap(find.text('Try again'));
      await _settle(tester);
      expect(find.byType(WithdrawalTrackerScreen), findsOneWidget);
    });
  });
}
