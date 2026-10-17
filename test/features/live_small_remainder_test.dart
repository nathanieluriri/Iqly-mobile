import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/settings/account_closing_screen.dart';
import 'package:iqly_mobile/features/settings/delete_account_screen.dart';
import 'package:iqly_mobile/features/wallet/withdraw_sheet.dart';
import 'package:iqly_mobile/features/wallet/withdrawal_pending_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/field.dart';

import '../data/live/live_data_fixtures.dart';
import '../support/live_launch.dart';

/// Contracts 6 and 3.4 for Ada: a withdrawal under ₦1,000 is refused
/// unless it is the whole withdrawable balance, and the close is refused
/// while money is left or a withdrawal is on its way.
class _Ada {
  _Ada({this.withdrawable = 50000, this.pending = 0});

  int withdrawable;
  int pending;
  bool offline = false;
  final made = <Map<String, Object?>>[];
  final closes = <String>[];

  void settle() {
    for (final row in made.where((w) => w['status'] == 'pending')) {
      row['status'] = 'completed';
      row['completedAt'] = '2026-10-17T09:30:00.000Z';
      pending -= row['amount']! as int;
    }
  }

  Map<String, Object?> get wallet => walletJson({
    'available': withdrawable + pending,
    'pendingWithdrawals': pending,
    'withdrawable': withdrawable,
    'totalEarned': 3000000,
  });

  Future<http.Response> answer(http.Request r) async {
    if (offline) throw http.ClientException('offline', r.url);
    switch ('${r.method} ${r.url.path}') {
      case 'POST /wallet/withdrawals':
        final amount = (jsonDecode(r.body) as Map)['amount'] as int;
        if (amount < 100000 && amount != withdrawable) {
          return refused(400, 'WITHDRAWAL_BELOW_MINIMUM');
        }
        if (amount > withdrawable) {
          return refused(409, 'WALLET_INSUFFICIENT_BALANCE');
        }
        withdrawable -= amount;
        pending += amount;
        final row = withdrawalJson({
          'id': 'w_${made.length + 1}',
          'amount': amount,
        });
        made.add(row);
        return ok(row, status: 201);
      case 'GET /wallet':
        return ok(wallet);
      case 'GET /wallet/withdrawals':
        return ok(page([...made]));
      case 'GET /wallet/bank-account':
        return ok(bankAccountJson());
      case 'GET /banks':
        return ok(banksJson);
      case 'POST /me/account/close':
        final code = withdrawable > 0
            ? 'ACCOUNT_HAS_BALANCE'
            : pending > 0
            ? 'WITHDRAWAL_IN_FLIGHT'
            : null;
        closes.add(code ?? 'closing');
        if (code != null) return refused(409, code);
        return ok({
          'status': 'closing',
          'closesAt': '2026-11-16T10:00:00.000Z',
        });
    }
    if (r.method == 'GET' && r.url.path.startsWith('/wallet/withdrawals/')) {
      final id = r.url.pathSegments.last;
      final row = made.where((w) => w['id'] == id).firstOrNull;
      return row == null ? refused(404, 'NOT_FOUND') : ok(row);
    }
    return ok(page([]));
  }

  ApiClient get api => ApiClient(
    tokens: MemoryTokenStore('t'),
    baseUrl: 'https://api.test',
    client: MockClient(answer),
  );
}

/// The phone's copy of a wallet at ₦0.00 with nothing on its way.
Future<MemoryLocalStore> _keptAtZero() async {
  final store = MemoryLocalStore(clock: () => launchNow);
  await store.writeCache(
    'u_1',
    LiveCacheKeys.wallet,
    walletJson({'available': 0, 'pendingWithdrawals': 0, 'withdrawable': 0}),
  );
  await store.writeCache('u_1', LiveCacheKeys.ledger, <Object>[]);
  await store.writeCache('u_1', LiveCacheKeys.withdrawals, <Object>[]);
  await store.writeCache('u_1', LiveCacheKeys.bankAccount, bankAccountJson());
  await store.writeCache('u_1', LiveCacheKeys.banks, banksJson);
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

Future<void> _amount(WidgetTester tester, String naira) async {
  await tester.enterText(
    find.descendant(
      of: find.byWidgetPredicate((w) => w is IqField && w.label == 'Amount'),
      matching: find.byType(EditableText),
    ),
    naira,
  );
  await tester.pump();
}

Future<void> _typeDelete(WidgetTester tester) async {
  await tester.enterText(find.byType(EditableText), 'delete');
  await tester.pumpAndSettle();
}

IqButton _delete(WidgetTester tester) => tester.widget<IqButton>(
  find.byWidgetPredicate(
    (w) => w is IqButton && w.label == 'Delete my account',
  ),
);

const _atZero =
    'Your wallet is at ₦0.00. Delete now and you have 30 days to change your '
    'mind.';

void main() {
  testWidgets('₦500.00 left: only the whole ₦500.00 leaves; Delete waits '
      'while it is on its way and unlocks at ₦0.00 once it has arrived', (
    tester,
  ) async {
    final ada = _Ada();
    final (_, router) = await pumpLiveLaunch(
      tester,
      Routes.wallet,
      api: ada.api,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Withdraw').first);
    await _settle(tester);
    expect(
      find.text('You can withdraw up to ₦500.00 right now'),
      findsOneWidget,
    );

    await _amount(tester, '300');
    await tester.tap(find.text('Withdraw').last);
    await _settle(tester);
    expect(find.text('Minimum withdrawal is ₦1,000.00.'), findsOneWidget);
    expect(ada.made, isEmpty);

    await _amount(tester, '500');
    expect(find.text('Minimum withdrawal is ₦1,000.00.'), findsNothing);
    await tester.tap(find.text('Withdraw').last);
    await _settle(tester);
    expect([for (final w in ada.made) w['amount']], [50000]);
    expect(find.byType(WithdrawSheet), findsNothing);
    expect(find.byType(WithdrawalPendingScreen), findsOneWidget);

    router.go(Routes.deleteAccount);
    await _settle(tester);
    expect(find.text('Your wallet is at ₦0.00.'), findsOneWidget);
    expect(find.text('₦500.00 on its way'), findsOneWidget);
    expect(find.text(_atZero), findsNothing);
    await _typeDelete(tester);
    expect(_delete(tester).disabled, isTrue);

    ada.settle();
    router.go(Routes.more);
    await _settle(tester);
    router.go(Routes.deleteAccount);
    await _settle(tester);
    expect(find.text(_atZero), findsOneWidget);
    expect(find.text('₦500.00 on its way'), findsNothing);
    await _typeDelete(tester);
    expect(_delete(tester).disabled, isFalse);
    await tester.tap(find.text('Delete my account'));
    await _settle(tester);
    expect(ada.closes, ['closing']);
    expect(find.byType(AccountClosingScreen), findsOneWidget);
  });

  testWidgets('a wallet kept at ₦0.00 that is not: the refusal reloads it '
      'and the page asks to withdraw the ₦500.00 first, never blaming the '
      'connection', (tester) async {
    final ada = _Ada()..offline = true;
    await pumpLiveLaunch(
      tester,
      Routes.deleteAccount,
      api: ada.api,
      store: await _keptAtZero(),
    );
    await _settle(tester);
    expect(find.text(_atZero), findsOneWidget);

    ada.offline = false;
    await _typeDelete(tester);
    await tester.tap(find.text('Delete my account'));
    await _settle(tester);
    expect(ada.closes, ['ACCOUNT_HAS_BALANCE']);
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(
      find.text(
        'Withdraw your ₦500.00 first. Delete unlocks at ₦0.00, then you have '
        '30 days to change your mind.',
      ),
      findsOneWidget,
    );
    expect(find.text('Withdraw ₦500.00 first'), findsOneWidget);
    expect(_delete(tester).disabled, isTrue);
    expect(find.text(DeleteAccountScreen.failedText), findsNothing);
    expect(find.text(DeleteAccountScreen.refusedText), findsNothing);
  });

  testWidgets('a withdrawal on its way the kept wallet does not know: the '
      'refusal reloads it and the page shows it on its way', (tester) async {
    final ada = _Ada(withdrawable: 0, pending: 50000)
      ..made.add(withdrawalJson({'amount': 50000}))
      ..offline = true;
    await pumpLiveLaunch(
      tester,
      Routes.deleteAccount,
      api: ada.api,
      store: await _keptAtZero(),
    );
    await _settle(tester);
    ada.offline = false;
    await _typeDelete(tester);
    await tester.tap(find.text('Delete my account'));
    await _settle(tester);
    expect(ada.closes, ['WITHDRAWAL_IN_FLIGHT']);
    expect(find.text('Your wallet is at ₦0.00.'), findsOneWidget);
    expect(find.text('₦500.00 on its way'), findsOneWidget);
    expect(_delete(tester).disabled, isTrue);
    expect(find.text(DeleteAccountScreen.failedText), findsNothing);
  });
}
