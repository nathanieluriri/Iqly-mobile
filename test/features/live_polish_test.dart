import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/deep_links.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/polls/polls_screen.dart';
import 'package:iqly_mobile/features/splash/patch_dialog.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/surfaces/widget_snapshot.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/empty_state.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/segmented.dart';
import 'package:iqly_mobile/ui/wallet_card.dart';

import '../data/live/live_data_fixtures.dart' show firstFeatures;
import '../golden/screens/app_harness.dart';
import '../golden/screens/more_harness.dart' show pumpMore;
import '../golden/screens/wallet_harness.dart';
import '../support/live_launch.dart';

/// A staging API with every brief closed: lists come back empty.
ApiClient _api() => ApiClient(
  tokens: MemoryTokenStore('t'),
  baseUrl: 'https://api.test',
  client: MockClient(
    (r) async => http.Response(
      jsonEncode({
        'success': true,
        'data': r.url.path == '/me'
            ? {'id': 'u_1', 'name': 'Ada Obi', 'email': 'ada@example.com'}
            : {'items': <Object>[], 'nextCursor': null, 'pageCount': 1},
      }),
      200,
    ),
  ),
);

/// Money waiting and earned, nothing on its way.
class _NothingOnItsWay extends WalletRepository {
  @override
  Future<List<Withdrawal>> withdrawals() async => const [];
}

class _SlowSignOut extends DemoAuthService {
  final gate = Completer<void>();

  @override
  Future<void> signOut() => gate.future;
}

void main() {
  group('a live launch without polls and activations hides them', () {
    test('their routes are hidden; a preview launch keeps them', () {
      final live = ProviderContainer(
        overrides: [
          liveModeProvider.overrideWithValue(Backend.of(firstFeatures)),
        ],
      );
      addTearDown(live.dispose);
      expect(hiddenRoute(live.read, Routes.polls), isTrue);
      expect(hiddenRoute(live.read, '${Routes.activations}/a1/proof'), isTrue);
      expect(hiddenRoute(live.read, Routes.home), isFalse);
      expect(hiddenRoute(live.read, Routes.pickBrief), isFalse);

      final preview = ProviderContainer(
        overrides: [liveModeProvider.overrideWithValue(Backend.preview)],
      );
      addTearDown(preview.dispose);
      expect(hiddenRoute(preview.read, Routes.polls), isFalse);
      expect(hiddenRoute(preview.read, Routes.activations), isFalse);
    });

    test('the home widget offers no polls and opens Discover', () {
      final snapshot = WidgetSnapshot.of(
        briefs: const [],
        polls: const [],
        now: launchNow,
        showPolls: false,
      );
      expect(snapshot.pollsOpen, 0);
      expect(snapshot.pollsRoute, DeepLinks.home);
    });

    testWidgets('a link to the polls lands on Discover', (tester) async {
      await pumpLiveLaunch(tester, Routes.polls, api: _api());
      await tester.pumpAndSettle();
      expect(find.byType(PollsScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Pick a brief: no sample activation, the centred empty state', (
      tester,
    ) async {
      await pumpLiveLaunch(tester, Routes.pickBrief, api: _api());
      await tester.pumpAndSettle();
      expect(find.text('Activations'), findsNothing);
      expect(find.text('Orchid Foods'), findsNothing);
      expect(find.byType(IqEmptyState), findsOneWidget);
      expect(find.text('No open briefs right now'), findsOneWidget);
      expect(find.byType(IqButton), findsNothing);
    });

    testWidgets('Discover: no polls or activations; See all briefs only on '
        'For you', (tester) async {
      await pumpLiveLaunch(tester, Routes.home, api: _api());
      await tester.pumpAndSettle();
      expect(find.text('Quick polls'), findsNothing);
      expect(find.text('Activations'), findsNothing);
      expect(find.text('No open briefs right now'), findsOneWidget);
      expect(find.text('See all briefs'), findsOneWidget);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('No open briefs right now'), findsOneWidget);
      expect(find.text('See all briefs'), findsNothing);
    });
  });

  testWidgets('the empty state centres its words and drops a button with '
      'nowhere to go', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
          body: IqEmptyFill(
            child: IqEmptyState(title: 'Nothing yet', action: 'Go'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IqButton), findsNothing);
    final title = tester.widget<Text>(find.text('Nothing yet'));
    expect(title.textAlign, TextAlign.center);
    final centre = tester.getCenter(find.byType(IqEmptyState));
    final page = tester.getCenter(find.byType(Scaffold));
    expect(centre.dx, moreOrLessEquals(page.dx, epsilon: 1));
    expect(centre.dy, moreOrLessEquals(page.dy, epsilon: 1));
  });

  group('Wallet', () {
    testWidgets('the card is full width with the eye inside it', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Routes.wallet,
        repository: WalletRepository(),
        overrides: walletOverrides(),
      );
      final card = tester.getRect(find.byType(IqWalletCard));
      final eye = tester.getRect(
        find.byWidgetPredicate((w) => w is IqIcon && w.icon == IqIcons.eye),
      );
      expect(card.width, 390 - 2 * IqSpace.s4);
      expect(
        card.contains(eye.topLeft) && card.contains(eye.bottomRight),
        isTrue,
      );
      expect(eye.right, lessThan(card.right));
      expect(eye.top, lessThan(card.center.dy));
    });

    testWidgets('a tab shows only for a balance that is not zero', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Routes.wallet,
        repository: _NothingOnItsWay(),
        overrides: walletOverrides(),
      );
      expect(find.byType(IqSegmented), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Earned'), findsOneWidget);
      expect(find.text('On its way'), findsNothing);
    });

    testWidgets('no activity: no tabs, no Recent card, the empty state', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Routes.wallet,
        repository: EmptyWalletRepository(),
        overrides: walletOverrides(),
      );
      expect(find.byType(IqSegmented), findsNothing);
      expect(find.text('Recent rewards'), findsNothing);
      expect(find.text('Recent activity'), findsNothing);
      expect(find.byType(IqEmptyState), findsOneWidget);
      expect(find.text('No activity yet'), findsOneWidget);
    });
  });

  testWidgets('Sign out covers the screen with the filling mark until the '
      'landing', (tester) async {
    final auth = _SlowSignOut();
    await pumpMore(
      tester,
      Routes.profile,
      overrides: [authServiceProvider.overrideWithValue(auth)],
    );
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(IqButton, 'Sign out'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(IqFillLoader), findsOneWidget);
    expect(find.text('Sign out?'), findsNothing);
    auth.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LandingScreen), findsOneWidget);
    expect(find.byType(IqFillLoader), findsNothing);
  });
}
