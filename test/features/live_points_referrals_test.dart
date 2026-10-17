import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/gift_button.dart';

import '../golden/screens/more_harness.dart';
import '../data/live/live_data_fixtures.dart' show firstFeatures;
import '../support/live_launch.dart';

ApiClient _api() => ApiClient(
  tokens: MemoryTokenStore('t'),
  baseUrl: 'https://api.test',
  client: MockClient(
    (r) async => http.Response(
      jsonEncode({
        'success': true,
        'data': r.url.path == '/me'
            ? {'id': 'u_1', 'name': 'Ada Obi', 'email': 'ada@example.com'}
            : {'items': <Object>[], 'nextCursor': null},
      }),
      200,
    ),
  ),
);

void main() {
  for (final (name, mode) in [
    ('without the leaderboard and referrals', Backend.of(firstFeatures)),
    ('the profile paused', Backend.of(const {LiveFeature.briefs})),
  ]) {
    group('a live launch, $name', () {
      testWidgets('More shows the name alone: no points, rank, invite card '
          'or Leaderboard', (tester) async {
        await pumpLiveLaunch(tester, Routes.more, api: _api(), mode: mode);
        await tester.pumpAndSettle();
        expect(find.text('Ada Obi'), findsOneWidget);
        for (final sample in ['1,240', 'iQL points', '#7', 'this month']) {
          expect(find.text(sample), findsNothing, reason: sample);
        }
        expect(find.textContaining('ADAEZE24'), findsNothing);
        expect(find.text('Invite friends, earn ₦500'), findsNothing);
        expect(find.text('Leaderboard'), findsNothing);
        expect(find.text('Quick polls'), findsNothing);
        expect(find.text('Activations'), findsNothing);
        expect(find.text('Saved briefs'), findsOneWidget);
      });

      testWidgets('Your profile has no invite code or Invite friends', (
        tester,
      ) async {
        await pumpLiveLaunch(tester, Routes.profile, api: _api(), mode: mode);
        await tester.pumpAndSettle();
        expect(find.text('Ada Obi'), findsOneWidget);
        expect(find.textContaining('Invite code'), findsNothing);
        expect(find.text('Invite friends'), findsNothing);
        expect(find.text('Your details'), findsOneWidget);
      });

      testWidgets('Discover has no gift to Referrals', (tester) async {
        await pumpLiveLaunch(tester, Routes.home, api: _api(), mode: mode);
        await tester.pumpAndSettle();
        expect(find.text('Discover'), findsWidgets);
        expect(find.byType(IqGiftButton), findsNothing);
      });
    });
  }

  testWidgets('the preview launch keeps them all', (tester) async {
    await pumpMore(tester, Routes.more);
    expect(find.text('1,240'), findsOneWidget);
    expect(find.text('#7'), findsOneWidget);
    expect(find.textContaining('ADAEZE24'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);
  });
}
