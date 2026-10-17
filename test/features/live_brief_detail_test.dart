import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/router.dart';

import '../data/live/live_data_fixtures.dart' show challengeJson, page;
import '../support/live_launch.dart';

/// A brief opened from a notification, a home widget or a link: closed, so
/// not in the Discover feed, and not kept on the phone.
class _Api {
  bool offline = true;
  int asked = 0;

  Future<http.Response> answer(http.Request r) async {
    if (r.url.path == '/challenges/c_9') asked++;
    if (offline) throw http.ClientException('offline', r.url);
    final body = switch (r.url.path) {
      '/challenges/c_9' => challengeJson({
        'id': 'c_9',
        'title': 'Why do people stop saving?',
        'status': 'closed',
      }),
      _ => page([]),
    };
    return http.Response(
      jsonEncode({'success': true, 'data': body}),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  ApiClient get client => ApiClient(
    tokens: MemoryTokenStore('t'),
    baseUrl: 'https://api.test',
    client: MockClient(answer),
  );
}

const _failed = 'Couldn’t load. Check your connection.';
const _title = 'Why do people stop saving?';

void main() {
  testWidgets('with no answer and no copy the page fails with Try again, '
      'which shows the brief once the API answers', (tester) async {
    final api = _Api();
    await pumpLiveLaunch(tester, Routes.brief('c_9'), api: api.client);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text(_failed), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    api.offline = false;
    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text(_title), findsWidgets);
    expect(find.text(_failed), findsNothing);
    expect(api.asked, 2);
  });

  testWidgets('a failure is not kept as the brief: opened again once the API '
      'answers, it asks again and shows it', (tester) async {
    final api = _Api();
    final (_, router) = await pumpLiveLaunch(
      tester,
      Routes.brief('c_9'),
      api: api.client,
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.text(_failed), findsOneWidget);

    api.offline = false;
    router.go(Routes.home);
    await tester.pump(const Duration(seconds: 2));
    router.push(Routes.brief('c_9'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text(_title), findsWidgets);
    expect(api.asked, 2);
  });
}
