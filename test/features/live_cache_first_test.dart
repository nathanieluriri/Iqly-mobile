import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/router.dart';

import '../data/live/live_data_fixtures.dart'
    show challengeJson, submissionJson;
import '../support/live_api.dart' show meJson;
import '../support/live_launch.dart';

/// The phone holds the briefs it loaded last time.
Future<MemoryLocalStore> _kept() async {
  final store = MemoryLocalStore(clock: () => launchNow);
  await store.writeCache('u_1', LiveCacheKeys.briefs, [
    challengeJson({'deadline': '2026-10-30T10:00:00.000Z'}),
  ]);
  return store;
}

ApiClient _api(Future<http.Response> Function(http.Request r) answer) =>
    ApiClient(
      tokens: MemoryTokenStore('t'),
      baseUrl: 'https://api.test',
      client: MockClient(answer),
    );

void main() {
  testWidgets('a network that never answers: Discover shows the briefs the '
      'phone holds within 3 s, not after the 20 s timeout', (tester) async {
    await pumpLiveLaunch(
      tester,
      Routes.home,
      api: _api((_) => Completer<http.Response>().future),
      store: await _kept(),
    );
    final shown = <int, bool>{};
    var at = 0;
    for (final second in [1, 2, 3, 5]) {
      await tester.pump(Duration(seconds: second - at));
      at = second;
      shown[second] = find.text('Make Sunday data day').evaluate().isNotEmpty;
    }
    expect(shown, {1: false, 2: false, 3: true, 5: true});
    await tester.pump(const Duration(seconds: 20));
  });

  testWidgets('an API that answers 503: Discover shows the briefs the phone '
      'holds, not "Couldn\'t load briefs"', (tester) async {
    await pumpLiveLaunch(
      tester,
      Routes.home,
      api: _api(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'error': {'code': 'SERVICE_UNAVAILABLE', 'message': 'down'},
          }),
          503,
        ),
      ),
      store: await _kept(),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Make Sunday data day'), findsOneWidget);
    expect(find.text('Couldn’t load briefs'), findsNothing);
  });

  for (final (route, shown) in [
    (Routes.more, 'Ada Obi'),
    (resultPath('s_1'), 'See the leaderboard'),
  ]) {
    testWidgets('$route on a network that never answers shows the account '
        'kept from GET /me within 3 s, as every other read', (tester) async {
      final store = MemoryLocalStore(clock: () => launchNow);
      await store.writeCache('u_1', AccountKeys.me, meJson());
      await store.writeCache('u_1', LiveCacheKeys.submissions, [
        submissionJson(),
      ]);
      await store.writeCache('u_1', AccountKeys.outcome('s_1'), {
        'submissionId': 's_1',
        'challengeId': 'c_9',
        'resultsPublishedAt': '2026-10-02T10:00:00.000Z',
        'entries': 36,
        'rank': 2,
        'leaders': [
          {'rank': 1, 'name': 'Tobi A.', 'amountKobo': 2500000, 'you': false},
        ],
      });
      await pumpLiveLaunch(
        tester,
        route,
        api: _api((_) => Completer<http.Response>().future),
        store: store,
      );
      await tester.pump(const Duration(milliseconds: 2900));
      expect(find.text(shown), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.text(shown), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
    });
  }
}
