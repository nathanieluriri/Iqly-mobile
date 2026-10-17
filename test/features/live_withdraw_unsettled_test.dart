import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/wallet/withdraw_sheet.dart';
import 'package:iqly_mobile/features/withdrawals/withdrawal_tracker_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/field.dart';

import '../data/live/live_data_fixtures.dart';
import '../support/live_launch.dart';

/// Contract 6 for one person: a withdrawal's Idempotency-Key answers the
/// row it made, and the balance falls with each row. [loseNextAnswer]
/// keeps the next row but never answers, as a dropped connection does.
class _Payouts {
  var withdrawable = 1500000;
  final made = <String, Map<String, Object?>>{};
  var loseNextAnswer = false;
  var walletReads = 0;

  Future<http.Response> answer(http.Request r) async {
    switch ('${r.method} ${r.url.path}') {
      case 'POST /wallet/withdrawals':
        final key = r.headers['idempotency-key']!;
        final amount = (jsonDecode(r.body) as Map)['amount'] as int;
        final known = made.containsKey(key);
        final row = made[key] ??= () {
          withdrawable -= amount;
          return withdrawalJson({
            'id': 'w_${made.length + 1}',
            'amount': amount,
          });
        }();
        if (loseNextAnswer) {
          loseNextAnswer = false;
          return Completer<http.Response>().future;
        }
        return ok(row, status: known ? 200 : 201);
      case 'GET /wallet':
        walletReads++;
        return ok(walletJson({'withdrawable': withdrawable}));
      case 'GET /wallet/withdrawals':
        return ok(page([...made.values]));
      case 'GET /wallet/bank-account':
        return ok(bankAccountJson());
      case 'GET /banks':
        return ok(banksJson);
    }
    return ok(page([]));
  }
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

void main() {
  testWidgets('a withdrawal whose answer is lost never reads "Nothing was '
      'sent"; the wallet reloads, and the next Withdraw, for another amount, '
      'finds the first: one payout, and its tracker opens', (tester) async {
    final server = _Payouts()..loseNextAnswer = true;
    await pumpLiveLaunch(
      tester,
      Routes.wallet,
      api: ApiClient(
        tokens: MemoryTokenStore('t'),
        baseUrl: 'https://api.test',
        client: MockClient(server.answer),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Withdraw').first);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.byType(WithdrawSheet), findsOneWidget);
    await _amount(tester, '5000');
    final reads = server.walletReads;
    await tester.tap(find.text('Withdraw').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();

    expect(server.made, hasLength(1), reason: 'the API kept the first');
    expect(find.text('No connection. Nothing was sent.'), findsNothing);
    expect(find.text('No connection.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(server.walletReads, greaterThan(reads), reason: 'reloaded');
    expect(
      find.text('You can withdraw up to ₦10,000.00 right now'),
      findsOneWidget,
    );

    await _amount(tester, '6000');
    await tester.tap(find.text('Withdraw').last);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(server.made, hasLength(1), reason: 'one payout for one intent');
    expect(server.withdrawable, 1000000);
    expect(find.byType(WithdrawSheet), findsNothing);
    expect(find.byType(WithdrawalTrackerScreen), findsOneWidget);
  });

  testWidgets('a connection refused before sending says nothing was sent, '
      'and the next amount goes as asked', (tester) async {
    final server = _Payouts();
    var refuse = true;
    await pumpLiveLaunch(
      tester,
      Routes.wallet,
      api: ApiClient(
        tokens: MemoryTokenStore('t'),
        baseUrl: 'https://api.test',
        client: MockClient((r) {
          if (r.method == 'POST' && refuse) {
            refuse = false;
            throw const SocketException(
              'Connection failed',
              osError: OSError('Connection refused', 111),
            );
          }
          return server.answer(r);
        }),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Withdraw').first);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await _amount(tester, '5000');
    await tester.tap(find.text('Withdraw').last);
    await tester.pumpAndSettle();
    expect(find.text('No connection. Nothing was sent.'), findsOneWidget);
    expect(server.made, isEmpty);

    await _amount(tester, '6000');
    await tester.tap(find.text('Withdraw').last);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect([for (final w in server.made.values) w['amount']], [600000]);
    expect(find.text('₦6,000.00 is on its way'), findsOneWidget);
  });
}
