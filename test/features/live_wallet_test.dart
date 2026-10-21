import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/money.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/live/mappers.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/wallet/pin_sheet.dart';
import 'package:iqly_mobile/features/wallet/wallet_state.dart';
import 'package:iqly_mobile/features/wallet/withdraw_sheet.dart';
import 'package:iqly_mobile/features/wallet/withdrawal_pending_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/live/live_data_fixtures.dart';
import '../golden/screens/app_harness.dart';
import '../golden/screens/wallet_harness.dart';

final _now = DateTime(2026, 10, 17, 10);

/// A live wallet: a ₦12,500.00 win, a settled ₦10,000.00 payout and its
/// reversal on the ledger, ₦10,000.00 on its way, and figures from
/// `GET /wallet` that are not the ledger's sum.
FakeApi _liveWallet() {
  final api = FakeApi();
  api.data(
    'GET',
    '/wallet/transactions',
    page([
      transactionJson(),
      transactionJson({
        'id': 't_2',
        'amount': -1000000,
        'type': 'withdrawal',
        'source': 'withdrawal',
        'submissionId': null,
        'businessName': null,
        'withdrawalId': 'w_0',
      }),
      transactionJson({
        'id': 't_3',
        'amount': 1000000,
        'type': 'reversal',
        'source': 'reversal',
        'submissionId': null,
        'businessName': null,
        'withdrawalId': 'w_0',
      }),
    ]),
  );
  api.data(
    'GET',
    '/wallet/withdrawals',
    page([
      withdrawalJson(),
      withdrawalJson({
        'id': 'w_0',
        'status': 'reversed',
        'createdAt': '2026-10-01T08:00:00.000Z',
      }),
    ]),
  );
  api.data('GET', '/wallet/bank-account', bankAccountJson());
  api.data('GET', '/banks', banksJson);
  api.data('GET', '/wallet', walletJson());
  api.data('GET', '/submissions/mine', page([submissionJson()]));
  return api;
}

Future<ProviderContainer> _container(
  FakeApi api, {
  Backend? mode,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({'session.userId': 'u_1'});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => _now),
      localStoreProvider.overrideWithValue(MemoryLocalStore(clock: () => _now)),
      ...liveOverrides(api.api(), mode: mode),
      ...overrides,
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Withdrawal _requested() =>
    withdrawalFromJson(withdrawalJson({'id': 'w_2', 'amount': 500000}))!;

void main() {
  group('a live wallet', () {
    test('shows the figures GET /wallet reports, not the ledger sum', () async {
      final c = await _container(_liveWallet());
      final data = await c.read(walletProvider.future);
      expect(data.reported, isNotNull);
      expect(naira(data.totals.totalEarnedKobo), '₦65,000.00');
      expect(naira(data.totals.pendingWithdrawalsKobo), '₦10,000.00');
      expect(naira(data.totals.withdrawableKobo), '₦15,000.00');
      final added = walletTotals(data.ledger, data.withdrawals);
      expect(added.totalEarnedKobo, 1250000, reason: 'what the rows add to');
      expect(data.savedBank!.label, 'Access Bank ••6789');
      expect(data.banks, hasLength(2));
    });

    test(
      'a reversal shows only as its withdrawal, never as a reward',
      () async {
        final c = await _container(_liveWallet());
        final data = await c.read(walletProvider.future);
        expect([for (final a in data.activity) a.key], ['w_1', 't_1', 'w_0']);
        expect(data.rewards, 1);
        expect(data.earnedCaption, 'From 1 reward');
      },
    );

    test('Earned so far counts every credit GET /wallet adds up', () async {
      final api = _liveWallet();
      api.data(
        'GET',
        '/wallet/transactions',
        page([
          transactionJson(),
          transactionJson({
            'id': 't_4',
            'amount': 150000,
            'source': 'activation',
            'submissionId': null,
            'businessName': 'Kudi Box',
          }),
          transactionJson({
            'id': 't_5',
            'amount': 50000,
            'source': 'referral',
            'submissionId': null,
            'businessName': null,
            'referredName': 'Ngozi E.',
          }),
          transactionJson({
            'id': 't_3',
            'amount': 1000000,
            'type': 'reversal',
            'source': 'reversal',
            'submissionId': null,
            'businessName': null,
            'withdrawalId': 'w_0',
          }),
        ]),
      );
      api.data('GET', '/wallet', walletJson({'totalEarned': 1450000}));
      final c = await _container(api);
      final data = await c.read(walletProvider.future);
      expect(data.earnedCaption, 'From 3 rewards');
      expect(
        data.ledger
            .where((l) => l.earned)
            .fold(0, (sum, l) => sum + l.amountKobo),
        data.totals.totalEarnedKobo,
      );
    });

    test('a demo activation credit leaves it as it is', () async {
      final c = await _container(_liveWallet());
      final before = await c.read(walletProvider.future);
      c
          .read(walletProvider.notifier)
          .credit(
            LedgerEntry(
              id: 'activation-a1',
              type: LedgerType.award,
              amountKobo: 150000,
              createdAt: _now,
              business: 'Kudi Box',
              note: 'activation',
            ),
          );
      final after = c.read(walletProvider).value!;
      expect(after.ledger, same(before.ledger));
      expect(after.totals.withdrawableKobo, before.totals.withdrawableKobo);
    });

    test('a withdrawal made and followed keeps the figures footing', () async {
      final c = await _container(_liveWallet());
      await c.read(walletProvider.future);
      final notifier = c.read(walletProvider.notifier);
      final requested = _requested();
      notifier.add(requested);
      var totals = c.read(walletProvider).value!.totals;
      expect(naira(totals.pendingWithdrawalsKobo), '₦15,000.00');
      expect(naira(totals.withdrawableKobo), '₦10,000.00');
      expect(naira(totals.totalEarnedKobo), '₦65,000.00');

      notifier.replace(
        requested.copyWith(status: WithdrawalStatus.processing, sentAt: _now),
      );
      totals = c.read(walletProvider).value!.totals;
      expect(naira(totals.pendingWithdrawalsKobo), '₦15,000.00');

      notifier.replace(
        requested.copyWith(
          status: WithdrawalStatus.completed,
          completedAt: _now,
        ),
      );
      final data = c.read(walletProvider).value!;
      expect(naira(data.totals.pendingWithdrawalsKobo), '₦10,000.00');
      expect(naira(data.totals.withdrawableKobo), '₦10,000.00');
      expect(
        data.ledger.any((l) => l.id == 'debit-w_2'),
        isFalse,
        reason: 'the API puts the debit on the ledger',
      );
    });

    test('a failed withdrawal gives its hold back', () async {
      final c = await _container(_liveWallet());
      await c.read(walletProvider.future);
      final notifier = c.read(walletProvider.notifier);
      final requested = _requested();
      notifier
        ..add(requested)
        ..replace(requested.copyWith(status: WithdrawalStatus.failed));
      final totals = c.read(walletProvider).value!.totals;
      expect(naira(totals.pendingWithdrawalsKobo), '₦10,000.00');
      expect(naira(totals.withdrawableKobo), '₦15,000.00');
    });

    test('a reload offline keeps what is on screen', () async {
      final api = _liveWallet();
      final c = await _container(api);
      await c.read(walletProvider.future);
      c.read(walletProvider.notifier).add(_requested());
      api.offline = true;
      await c.read(walletProvider.notifier).refreshQuietly();
      final data = c.read(walletProvider).value!;
      expect(naira(data.totals.withdrawableKobo), '₦10,000.00');
      expect(data.withdrawal('w_2'), isNotNull);
    });

    test('a reload brings the API rows and figures', () async {
      final api = _liveWallet();
      final c = await _container(api);
      await c.read(walletProvider.future);
      c.read(walletProvider.notifier).add(_requested());
      api.data('GET', '/wallet', walletJson({'withdrawable': 1000000}));
      api.data(
        'GET',
        '/wallet/withdrawals',
        page([
          withdrawalJson({
            'id': 'w_1',
            'status': 'completed',
            'completedAt': '2026-10-17T09:00:00.000Z',
          }),
        ]),
      );
      await c.read(walletProvider.notifier).refreshQuietly();
      final data = c.read(walletProvider).value!;
      expect(naira(data.totals.withdrawableKobo), '₦10,000.00');
      expect(data.withdrawal('w_1')!.status, WithdrawalStatus.completed);
      expect(
        data.withdrawal('w_2'),
        isNotNull,
        reason: 'a withdrawal the reload does not have yet stays',
      );
    });

    test('opens offline on the last copy', () async {
      final api = _liveWallet();
      final c = await _container(api);
      await c.read(walletProvider.future);
      api.offline = true;
      c.invalidate(walletProvider);
      final data = await c.read(walletProvider.future);
      expect(naira(data.totals.withdrawableKobo), '₦15,000.00');
      expect(data.withdrawals, hasLength(2));
    });

    test('a saved account replaces the one the API kept', () async {
      final c = await _container(_liveWallet());
      await c.read(walletProvider.future);
      c
          .read(walletProvider.notifier)
          .addAccount(
            const SavedBank(
              bankCode: '058',
              bankName: 'Guaranty Trust Bank',
              accountName: 'ADAEZE OKAFOR',
              accountNumber: '4410',
            ),
          );
      final accounts = c.read(walletProvider).value!.accounts;
      expect(
        [for (final a in accounts) a.label],
        ['Guaranty Trust Bank ••4410'],
      );
    });

    test('reward rows name a closed brief from the entry', () async {
      final c = await _container(_liveWallet());
      final briefs = await c.read(rewardBriefsProvider.future);
      expect(briefs['s_1']!.title, 'Why do people stop saving?');
      expect(briefs['s_1']!.businessName, 'Orchid Foods');
    });

    test('paused withdrawals leave no rows, none of the demo\'s, and the '
        'API figures as they are', () async {
      final api = _liveWallet();
      final c = await _container(
        api,
        mode: Backend.of({LiveFeature.profile, LiveFeature.wallet}),
      );
      final data = await c.read(walletProvider.future);
      expect(data.withdrawals, isEmpty);
      expect(data.activity.map((a) => a.key), ['t_1']);
      expect(naira(data.totals.withdrawableKobo), '₦15,000.00');
      expect(api.to('/wallet/withdrawals'), isEmpty);
      c.read(walletProvider.notifier).add(_requested());
      expect(
        c.read(walletProvider).value!.totals.withdrawableKobo,
        data.totals.withdrawableKobo,
      );
    });
  });

  test('preview adds its figures up from the rows, as before', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        repositoryProvider.overrideWithValue(DemoRepository(DemoData())),
      ],
    );
    addTearDown(c.dispose);
    final data = await c.read(walletProvider.future);
    expect(data.reported, isNull);
    expect(naira(data.totals.totalEarnedKobo), '₦65,000.00');
    expect(naira(data.totals.withdrawableKobo), '₦15,000.00');
  });

  group('withdraw', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
    }

    Future<void> withdraw(WidgetTester tester) async {
      await tester.tap(find.text('Withdraw').first);
      await settle(tester);
      expect(find.byType(WithdrawSheet), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is IqField && w.label == 'Amount',
          ),
          matching: find.byType(EditableText),
        ),
        '5000',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw').last);
      await settle(tester);
    }

    testWidgets('live: no PIN, straight to the request', (tester) async {
      final api = _liveWallet();
      final requested = withdrawalJson({'id': 'w_2', 'amount': 500000});
      api.on('POST', '/wallet/withdrawals', (_) {
        api
          ..data(
            'GET',
            '/wallet/withdrawals',
            page([requested, withdrawalJson()]),
          )
          ..data(
            'GET',
            '/wallet',
            walletJson({
              'pendingWithdrawals': 1500000,
              'withdrawable': 1000000,
            }),
          );
        return ok(requested, status: 201);
      });
      final store = MemoryLocalStore(clock: () => _now);
      await pumpApp(
        tester,
        Routes.wallet,
        clock: () => _now,
        repository: LiveRepository(
          api: api.api(),
          store: store,
          mode: allLive,
          demo: DemoRepository(DemoData(now: _now)),
          userId: 'u_1',
          clock: () => _now,
        ),
        overrides: [
          ...liveOverrides(api.api()),
          localStoreProvider.overrideWithValue(store),
        ],
      );
      await withdraw(tester);
      expect(find.byType(PinSheet), findsNothing);
      expect(api.to('/wallet/withdrawals', method: 'POST'), hasLength(1));
      expect(find.byType(WithdrawalPendingScreen), findsOneWidget);
      expect(find.text('₦5,000.00 is on its way'), findsOneWidget);
      expect(find.text('₦10,000.00'), findsOneWidget);
    });

    testWidgets('preview: the PIN as before', (tester) async {
      final wallet = instantWallet();
      await pumpApp(
        tester,
        Routes.wallet,
        repository: WalletRepository(),
        overrides: walletOverrides(wallet: wallet),
      );
      await withdraw(tester);
      expect(find.byType(PinSheet), findsOneWidget);
      expect(wallet.requests, isEmpty);
    });
  });
}
