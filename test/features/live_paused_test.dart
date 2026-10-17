import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/entry/entry_state.dart';
import 'package:iqly_mobile/features/notifications/notifications_state.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/features/settings/account_closing_screen.dart';
import 'package:iqly_mobile/features/settings/delete_account_screen.dart';
import 'package:iqly_mobile/features/settings/restore_account_screen.dart';
import 'package:iqly_mobile/features/settings/settings_state.dart';
import 'package:iqly_mobile/features/wallet/pin_sheet.dart';
import 'package:iqly_mobile/features/wallet/wallet_state.dart';
import 'package:iqly_mobile/features/wallet/withdraw_sheet.dart';
import 'package:iqly_mobile/features/wallet/withdrawal_pending_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/live/live_data_fixtures.dart';
import '../support/live_launch.dart';

/// A live launch whose health switched [off] off, and every feature that
/// needs it with it.
Backend _without(Set<LiveFeature> off) =>
    Backend.of(LiveFeature.values.where((f) => !off.contains(f)));

/// One person's API as contract 6 and 3 answer: ₦20,000.00 to withdraw
/// (or [withdrawable]), Access Bank ••6789 on file, one real withdrawal.
/// Every request is kept.
class _Api {
  _Api({this.withdrawable = 2000000});

  final int withdrawable;
  final requests = <http.Request>[];

  List<String> get routes => [
    for (final r in requests) '${r.method} ${r.url.path}',
  ];

  http.Response _ok(Object? data) => http.Response(
    jsonEncode({'success': true, 'data': data}),
    200,
    headers: {'content-type': 'application/json'},
  );

  late final client = ApiClient(
    tokens: MemoryTokenStore('t'),
    baseUrl: 'https://api.test',
    client: MockClient((r) async {
      requests.add(r);
      return switch ('${r.method} ${r.url.path}') {
        'GET /wallet' => _ok(
          walletJson({
            'pendingWithdrawals': 0,
            'withdrawable': withdrawable,
            'available': withdrawable,
            'totalEarned': 3000000,
          }),
        ),
        'GET /wallet/withdrawals' => _ok(
          page([
            withdrawalJson({'status': 'completed'}),
          ]),
        ),
        'GET /wallet/bank-account' => _ok(bankAccountJson()),
        'GET /banks' => _ok(banksJson),
        'GET /me' => _ok({
          'id': 'u_1',
          'name': 'Ada Obi',
          'email': 'ada@example.com',
          'status': 'closing',
          'closesAt': '2026-11-16T09:00:00.000Z',
          'profile': null,
        }),
        _ => _ok(page([])),
      };
    }),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byWidgetPredicate((w) => w is IqField && w.label == label),
      matching: find.byType(EditableText),
    ),
    text,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('withdrawals paused', () {
    testWidgets('the live wallet holds none of the sample withdrawals; '
        'Withdraw asks no PIN, sends nothing and says nothing was sent', (
      tester,
    ) async {
      final api = _Api();
      await pumpLiveLaunch(
        tester,
        Routes.wallet,
        api: api.client,
        mode: _without({LiveFeature.withdrawals}),
      );
      await tester.pumpAndSettle();
      expect(find.text('₦20,000.00'), findsWidgets);
      for (final sample in ['₦40,000.00', '₦2,000.00', '₦5,000.00']) {
        expect(find.textContaining(sample), findsNothing, reason: sample);
      }
      expect(api.routes, isNot(contains('GET /wallet/withdrawals')));

      await tester.tap(find.text('Withdraw').first);
      await _settle(tester);
      expect(find.byType(WithdrawSheet), findsOneWidget);
      await _type(tester, 'Amount', '5000');
      await tester.tap(find.text('Withdraw').last);
      await _settle(tester);
      expect(find.byType(PinSheet), findsNothing);
      expect(find.byType(WithdrawalPendingScreen), findsNothing);
      expect(find.text('Couldn’t send. Nothing was sent.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('₦5,000.00 is on its way'), findsNothing);
      expect(api.routes, isNot(contains('POST /wallet/withdrawals')));
    });
  });

  group('wallet paused', () {
    testWidgets('the Wallet fails into its failed state, with none of the '
        'sample figures', (tester) async {
      final api = _Api();
      final (c, _) = await pumpLiveLaunch(
        tester,
        Routes.wallet,
        api: api.client,
        mode: _without({LiveFeature.wallet}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Couldn\'t load your wallet'), findsOneWidget);
      expect(find.textContaining('₦15,000.00'), findsNothing);
      expect(find.textContaining('₦65,000.00'), findsNothing);
      expect(c.read(walletProvider).hasError, isTrue);
      await expectLater(
        c.read(accountWalletProvider.future),
        throwsA(isA<FeaturePaused>()),
      );
      expect(api.routes.where((r) => r.contains('/wallet')), isEmpty);
    });

    testWidgets('Delete account names no balance and refuses before '
        'anything is sent; the person stays signed in', (tester) async {
      final api = _Api();
      final (c, router) = await pumpLiveLaunch(
        tester,
        Routes.deleteAccount,
        api: api.client,
        mode: _without({LiveFeature.wallet}),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Withdraw'), findsNothing);
      expect(find.textContaining('Your wallet is at'), findsNothing);
      await _type(tester, 'Type delete to confirm', 'delete');
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      expect(find.text(DeleteAccountScreen.refusedText), findsOneWidget);
      expect(find.text(DeleteAccountScreen.failedText), findsNothing);
      expect(find.byType(AccountClosingScreen), findsNothing);
      expect(router.state.uri.path, Routes.deleteAccount);
      expect(c.read(sessionProvider).signedIn, isTrue);
      expect(api.routes, isNot(contains('POST /me/account/close')));
    });
  });

  group('account paused', () {
    testWidgets('Delete account at ₦0.00 refuses before anything is sent', (
      tester,
    ) async {
      final api = _Api(withdrawable: 0);
      final (c, _) = await pumpLiveLaunch(
        tester,
        Routes.deleteAccount,
        api: api.client,
        mode: _without({LiveFeature.account}),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Your wallet is at ₦0.00'), findsOneWidget);
      await _type(tester, 'Type delete to confirm', 'delete');
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      expect(find.text(DeleteAccountScreen.refusedText), findsOneWidget);
      expect(find.byType(AccountClosingScreen), findsNothing);
      expect(c.read(sessionProvider).signedIn, isTrue);
      expect(api.routes, isNot(contains('POST /me/account/close')));
    });

    testWidgets('a closing account still signs in to Restore', (tester) async {
      final api = _Api();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            apiClientProvider.overrideWithValue(api.client),
            localStoreProvider.overrideWithValue(MemoryLocalStore()),
            backendProvider.overrideWith(
              () => FixedBackend(_without({LiveFeature.account})),
            ),
          ],
          child: Consumer(
            builder: (context, r, _) {
              ref = r;
              return const SizedBox();
            },
          ),
        ),
      );
      final landing = await completeSignIn(
        ref,
        newAccount: false,
        name: 'Ada Obi',
        userId: 'u_1',
      );
      expect(landing.route, Routes.restoreAccount);
      expect(landing.extra, DateTime.utc(2026, 11, 16, 9).toLocal());
    });

    testWidgets('Restore refuses and stays; nothing is sent', (tester) async {
      final api = _Api();
      final (_, router) = await pumpLiveLaunch(
        tester,
        Routes.restoreAccount,
        api: api.client,
        mode: _without({LiveFeature.account}),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore my account'));
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t send.'), findsOneWidget);
      expect(find.text(ClosingLayout.failedText), findsNothing);
      expect(find.byType(RestoreAccountScreen), findsOneWidget);
      expect(router.state.uri.path, Routes.restoreAccount);
      expect(api.routes, isNot(contains('POST /me/account/restore')));
    });
  });

  group('other features paused', () {
    testWidgets('notifications: the feed fails into its failed state and the '
        'bell has nothing to count', (tester) async {
      final api = _Api();
      final (c, _) = await pumpLiveLaunch(
        tester,
        Routes.notifications,
        api: api.client,
        mode: _without({LiveFeature.notifications}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t load. Check your connection.'), findsWidgets);
      expect(c.read(notificationsProvider).hasError, isTrue);
      expect(await c.read(unreadNotificationsProvider.future), 0);
      expect(api.routes.where((r) => r.contains('/notifications')), isEmpty);
    });

    testWidgets('profile: Your details shows none of the sample details', (
      tester,
    ) async {
      final api = _Api();
      final (c, _) = await pumpLiveLaunch(
        tester,
        Routes.yourDetails,
        api: api.client,
        mode: _without({LiveFeature.profile}),
      );
      await tester.pumpAndSettle();
      expect(find.text('+234 801 234 5678'), findsNothing);
      expect(find.text('14 March 1998'), findsNothing);
      expect(c.read(accountDetailsProvider).hasError, isTrue);
      expect(api.routes.where((r) => r.contains('/profiles')), isEmpty);
    });
  });
}
