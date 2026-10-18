import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/live/live_wallet_service.dart';
import 'package:iqly_mobile/data/live/mappers.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/wallet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_data_fixtures.dart';

const _account = SavedBank(
  bankCode: '044',
  bankName: 'Access Bank',
  accountName: 'ADAEZE OKAFOR',
  accountNumber: '6789',
);

void main() {
  late FakeApi api;
  late LiveWalletService service;

  setUp(() {
    api = FakeApi();
    service = LiveWalletService(api.api());
  });

  group('bank checks', () {
    test('resolves the name the bank holds', () async {
      api.data('POST', '/banks/resolve', {
        'bankCode': '044',
        'accountNumber': '0123456789',
        'accountName': 'ADAEZE OKAFOR',
      });
      final result = await service.verifyAccount(
        bankCode: '044',
        accountNumber: '0123456789',
      );
      expect(result.accountName, 'ADAEZE OKAFOR');
      expect(jsonDecode(api.requests.single.body), {
        'bankCode': '044',
        'accountNumber': '0123456789',
      });
    });

    test('a number the bank cannot match is unverified', () async {
      api.on(
        'POST',
        '/banks/resolve',
        (_) => refused(400, 'BANK_ACCOUNT_RESOLVE_FAILED', 'Cannot resolve'),
      );
      final failed = await service.verifyAccount(
        bankCode: '044',
        accountNumber: '0123456780',
      );
      expect(failed.failure, WalletFailure.unverified);
      api.on('POST', '/banks/resolve', (_) => refused(429, 'RATE_LIMITED'));
      expect(
        (await service.verifyAccount(
          bankCode: '044',
          accountNumber: '0123456780',
        )).failure,
        WalletFailure.unknown,
      );
      api.offline = true;
      expect(
        (await service.verifyAccount(
          bankCode: '044',
          accountNumber: '0123456780',
        )).failure,
        WalletFailure.offline,
      );
    });

    test('saving puts the account, answered by its last four digits', () async {
      api.data('PUT', '/wallet/bank-account', bankAccountJson());
      final saved = await service.addAccount(
        const SavedBank(
          bankCode: '044',
          bankName: 'Access Bank',
          accountName: 'ADAEZE OKAFOR',
          accountNumber: '0123456789',
        ),
      );
      expect(jsonDecode(api.requests.single.body), {
        'bankCode': '044',
        'accountNumber': '0123456789',
      });
      expect(saved.accountNumber, '6789');
      expect(saved.label, 'Access Bank ••6789');
    });

    test('a save the API refuses throws', () async {
      api.on(
        'PUT',
        '/wallet/bank-account',
        (_) => refused(403, 'ACCOUNT_CLOSING'),
      );
      await expectLater(
        service.addAccount(_account),
        throwsA(
          isA<ApiRefused>().having((e) => e.code, 'code', 'ACCOUNT_CLOSING'),
        ),
      );
      api.offline = true;
      await expectLater(
        service.addAccount(_account),
        throwsA(isA<ApiUnreachable>()),
      );
    });

    test('with one account the default never changes', () async {
      await service.setDefault(_account);
      expect(api.requests, isEmpty);
    });
  });

  group('withdraw', () {
    test('posts the amount with an Idempotency-Key', () async {
      api.data('POST', '/wallet/withdrawals', withdrawalJson(), status: 201);
      final result = await service.withdraw(
        amountKobo: 1000000,
        account: _account,
      );
      final request = api.requests.single;
      expect(jsonDecode(request.body), {'amount': 1000000});
      expect(request.headers['idempotency-key'], hasLength(36));
      final w = result.withdrawal!;
      expect(w.id, 'w_1');
      expect(w.status, WithdrawalStatus.pending);
      expect(w.reference, 'IQ-WD-261017-K7QM');
      expect(w.destination, 'Access Bank ••6789');
      expect(result.earlier, isFalse);
    });

    test('a retry of the same request keeps its key', () async {
      api.offline = true;
      expect(
        (await service.withdraw(
          amountKobo: 1000000,
          account: _account,
        )).failure,
        WalletFailure.offline,
      );
      api.offline = false;
      api.on('POST', '/wallet/withdrawals', (_) => refused(502, 'BAD_GATEWAY'));
      await service.withdraw(amountKobo: 1000000, account: _account);
      api.data('POST', '/wallet/withdrawals', withdrawalJson());
      expect(
        (await service.withdraw(amountKobo: 1000000, account: _account)).ok,
        isTrue,
      );
      final keys = [for (final r in api.requests) r.headers['idempotency-key']];
      expect(keys, hasLength(3));
      expect(keys.toSet(), hasLength(1));

      await service.withdraw(amountKobo: 1000000, account: _account);
      expect(api.requests.last.headers['idempotency-key'], isNot(keys.first));
    });

    test('after a refusal, a different amount is a new request', () async {
      api.on('POST', '/wallet/withdrawals', (_) => refused(400, 'TOO_LOW'));
      await service.withdraw(amountKobo: 1000000, account: _account);
      await service.withdraw(amountKobo: 500000, account: _account);
      expect(
        api.requests.first.headers['idempotency-key'],
        isNot(api.requests.last.headers['idempotency-key']),
      );
      expect(jsonDecode(api.requests.last.body), {'amount': 500000});
    });

    test('a refusal the person can act on keeps its reason; any other reads '
        'as unknown, no connection as offline', () async {
      for (final (status, code, failure) in [
        (409, 'WALLET_INSUFFICIENT_BALANCE', WalletFailure.unknown),
        (409, 'PROFILE_INCOMPLETE', WalletFailure.profileIncomplete),
        (403, 'UNDER_AGE', WalletFailure.underAge),
        (400, 'WITHDRAWAL_BELOW_MINIMUM', WalletFailure.belowMinimum),
        (400, 'WITHDRAWAL_ABOVE_MAXIMUM', WalletFailure.aboveMaximum),
        (409, 'WITHDRAWAL_NO_BANK_ACCOUNT', WalletFailure.unknown),
        (403, 'ACCOUNT_CLOSING', WalletFailure.closing),
      ]) {
        api.on('POST', '/wallet/withdrawals', (_) => refused(status, code));
        final result = await service.withdraw(
          amountKobo: 1000000,
          account: _account,
        );
        expect(result.failure, failure, reason: code);
        expect(result.unsettled, isFalse, reason: code);
      }
      api.on(
        'POST',
        '/wallet/withdrawals',
        (_) => refused(429, 'RATE_LIMITED', 'Slow down', {'retry-after': '30'}),
      );
      final throttled = await service.withdraw(
        amountKobo: 1000000,
        account: _account,
      );
      expect(throttled.failure, WalletFailure.unknown);
      expect(throttled.unsettled, isTrue);
      api.offline = true;
      expect(
        (await service.withdraw(
          amountKobo: 1000000,
          account: _account,
        )).failure,
        WalletFailure.offline,
      );
    });

    test('paused withdrawals refuse before anything is sent', () async {
      final wallet = LiveWalletService(api.api(), withdrawals: false);
      final result = await wallet.withdraw(
        amountKobo: 1000000,
        account: _account,
      );
      expect(result.failure, WalletFailure.unknown);
      expect(result.unsettled, isFalse);
      expect(api.requests, isEmpty);
      expect(await wallet.confirmPin('1234'), isFalse);
      final pending = withdrawalFromJson(withdrawalJson())!;
      expect(await wallet.watch(pending).toList(), [pending]);
      expect(api.requests, isEmpty);
    });
  });

  group('a withdrawal whose answer was lost', () {
    /// Contract 6 for one person: a key answers the row it made (200) or
    /// makes one (201), and the balance falls with each. [then] says what
    /// happens to each request in turn after the row is made or found: null
    /// answers it, anything else is thrown in place of the answer.
    late Map<String, Map<String, Object?>> made;
    late List<Object? Function(http.Request request)> then;

    setUp(() {
      made = {};
      then = [];
      api.on('POST', '/wallet/withdrawals', (r) {
        final key = r.headers['idempotency-key']!;
        final amount = (jsonDecode(r.body) as Map)['amount'] as int;
        final step = then.isEmpty ? null : then.removeAt(0);
        final before = step?.call(r);
        if (before is http.Response) return before;
        if (before is SocketException) throw before;
        final known = made.containsKey(key);
        final row = made[key] ??= withdrawalJson({
          'id': 'w_${made.length + 1}',
          'amount': amount,
        });
        if (before != null) throw before;
        return ok(row, status: known ? 200 : 201);
      });
    });

    Object? lost(http.Request _) =>
        http.ClientException('Connection closed before full header');

    List<String?> keys() => [
      for (final r in api.requests) r.headers['idempotency-key'],
    ];

    List<Object?> amounts() => [
      for (final r in api.requests) (jsonDecode(r.body) as Map)['amount'],
    ];

    test('stays unsettled, and the next request, whatever its amount, sends '
        'it again first: what it made is the answer', () async {
      then.add(lost);
      final first = await service.withdraw(
        amountKobo: 500000,
        account: _account,
      );
      expect(first.failure, WalletFailure.offline);
      expect(first.unsettled, isTrue);
      expect(made, hasLength(1), reason: 'the API kept it');

      final second = await service.withdraw(
        amountKobo: 600000,
        account: _account,
      );
      expect(second.withdrawal!.id, 'w_1');
      expect(second.withdrawal!.amountKobo, 500000);
      expect(second.earlier, isTrue);
      expect(made, hasLength(1), reason: 'the new amount was not sent');
      expect(keys().toSet(), hasLength(1));
      expect(amounts(), [500000, 500000]);

      final third = await service.withdraw(
        amountKobo: 600000,
        account: _account,
      );
      expect(third.earlier, isFalse);
      expect(made, hasLength(2));
      expect(keys().last, isNot(keys().first));
      expect(amounts().last, 600000);
    });

    test('a definite refusal of it lets the new amount go, under a new '
        'key', () async {
      then
        ..add((_) => refused(503, 'SERVICE_UNAVAILABLE'))
        ..add((_) => refused(409, 'WALLET_INSUFFICIENT_BALANCE'));
      final first = await service.withdraw(
        amountKobo: 500000,
        account: _account,
      );
      expect(first.failure, WalletFailure.unknown);
      expect(first.unsettled, isTrue);
      final second = await service.withdraw(
        amountKobo: 600000,
        account: _account,
      );
      expect(second.withdrawal!.amountKobo, 600000);
      expect(second.earlier, isFalse);
      expect(amounts(), [500000, 500000, 600000]);
      expect(keys()[0], keys()[1]);
      expect(keys()[2], isNot(keys()[0]));
    });

    test('no answer again refuses again and sends nothing new', () async {
      then
        ..add(lost)
        ..add(lost)
        ..add(
          (_) => const SocketException(
            'Connection failed',
            osError: OSError('Connection refused', 111),
          ),
        );
      for (var i = 0; i < 3; i++) {
        final result = await service.withdraw(
          amountKobo: 600000 + i,
          account: _account,
        );
        expect(result.ok, isFalse);
        expect(result.unsettled, isTrue, reason: 'attempt $i');
      }
      expect(amounts(), [600000, 600000, 600000]);
      expect(keys().toSet(), hasLength(1));
    });

    test('408, 429 and server faults leave it unsettled', () async {
      for (final status in [408, 429, 500, 502, 503]) {
        final wallet = LiveWalletService(api.api());
        then.add((_) => refused(status, 'NO'));
        final result = await wallet.withdraw(
          amountKobo: 500000,
          account: _account,
        );
        expect(result.unsettled, isTrue, reason: '$status');
      }
    });

    test('a lookup or a connection that failed before sending settles it: '
        'nothing was sent, and the next amount is a new request', () async {
      for (final failed in [
        const SocketException(
          'Connection failed',
          osError: OSError('Connection refused', 111),
        ),
        const SocketException("Failed host lookup: 'api.iqly.net'"),
      ]) {
        api.requests.clear();
        then.add((_) => failed);
        final first = await service.withdraw(
          amountKobo: 500000,
          account: _account,
        );
        expect(first.failure, WalletFailure.offline);
        expect(first.unsettled, isFalse);
        expect(made, isEmpty);
        final second = await service.withdraw(
          amountKobo: 600000,
          account: _account,
        );
        expect(second.withdrawal!.amountKobo, 600000);
        expect(amounts(), [500000, 600000]);
        expect(keys().toSet(), hasLength(2));
        made.clear();
      }
    });
  });

  group('watch', () {
    /// Answers each poll with the next of [statuses], the last repeating.
    void answering(List<Map<String, Object?>> changes) {
      var poll = 0;
      api.on('GET', '/wallet/withdrawals/w_1', (_) {
        final change =
            changes[poll < changes.length ? poll : changes.length - 1];
        poll++;
        return ok(withdrawalJson(change));
      });
    }

    final pending = withdrawalFromJson(withdrawalJson())!;

    test('polls every 5 s while on hold and stops on a final status', () {
      fakeAsync((async) {
        answering([
          {},
          {'status': 'processing', 'sentAt': '2026-10-17T08:01:00.000Z'},
          {'status': 'processing', 'sentAt': '2026-10-17T08:01:00.000Z'},
          {
            'status': 'completed',
            'sentAt': '2026-10-17T08:01:00.000Z',
            'completedAt': '2026-10-17T08:03:00.000Z',
          },
        ]);
        final seen = <WithdrawalStatus>[];
        var done = false;
        service
            .watch(pending)
            .listen((w) => seen.add(w.status), onDone: () => done = true);
        async.flushMicrotasks();
        expect(seen, [WithdrawalStatus.pending]);
        expect(api.requests, hasLength(1), reason: 'asks at once');

        async.elapse(const Duration(seconds: 5));
        expect(seen, [WithdrawalStatus.pending, WithdrawalStatus.processing]);
        async.elapse(const Duration(seconds: 5));
        expect(seen, hasLength(2), reason: 'no change, nothing passed on');
        async.elapse(const Duration(seconds: 5));
        expect(seen.last, WithdrawalStatus.completed);
        expect(done, isTrue);
        expect(api.requests, hasLength(4));

        async.elapse(const Duration(minutes: 5));
        expect(api.requests, hasLength(4));
      });
    });

    test('a dropped connection waits for the next poll', () {
      fakeAsync((async) {
        answering([
          {'status': 'failed', 'failureReason': 'Account name mismatch'},
        ]);
        api.offline = true;
        final seen = <Withdrawal>[];
        service.watch(pending).listen(seen.add);
        async.elapse(const Duration(seconds: 10));
        expect(seen, hasLength(1));
        expect(api.requests, hasLength(3));
        api.offline = false;
        async.elapse(const Duration(seconds: 5));
        expect(seen.last.status, WithdrawalStatus.failed);
        expect(seen.last.failureReason, 'Account name mismatch');
        async.elapse(const Duration(minutes: 1));
        expect(api.requests, hasLength(4));
      });
    });

    test('stops when the listener goes', () {
      fakeAsync((async) {
        answering([{}]);
        final watching = service.watch(pending).listen((_) {});
        async.elapse(const Duration(seconds: 12));
        expect(api.requests, hasLength(3));
        unawaited(watching.cancel());
        async.elapse(const Duration(minutes: 1));
        expect(api.requests, hasLength(3));
      });
    });

    test('a final withdrawal is passed on once, never asked after', () {
      fakeAsync((async) {
        final completed = withdrawalFromJson(
          withdrawalJson({'status': 'completed'}),
        )!;
        final seen = <Withdrawal>[];
        var done = false;
        service.watch(completed).listen(seen.add, onDone: () => done = true);
        async.elapse(const Duration(minutes: 1));
        expect(seen, [completed]);
        expect(done, isTrue);
        expect(api.requests, isEmpty);
      });
    });
  });

  group('the provider', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'session.signedIn': true,
        'session.userId': 'u_1',
      });
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer container(List<Override> overrides) {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...overrides,
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'a withdrawal left unsettled never goes for the next person',
      () async {
        api.on(
          'POST',
          '/wallet/withdrawals',
          (_) => throw http.ClientException('Connection closed'),
        );
        final c = container(liveOverrides(api.api()));
        final first = await c
            .read(walletServiceProvider)
            .withdraw(amountKobo: 500000, account: _account);
        expect(first.unsettled, isTrue);
        final session = c.read(sessionProvider.notifier);
        await session.setSignedIn(false);
        await session.setUserId(null);
        await session.setUserId('u_2');
        await session.setSignedIn(true);
        api.data('POST', '/wallet/withdrawals', withdrawalJson(), status: 201);
        final next = await c
            .read(walletServiceProvider)
            .withdraw(amountKobo: 600000, account: _account);
        expect(next.earlier, isFalse);
        expect(jsonDecode(api.requests.last.body), {'amount': 600000});
        expect(
          api.requests.last.headers['idempotency-key'],
          isNot(api.requests.first.headers['idempotency-key']),
        );
      },
    );

    test('the wallet live takes the API; withdrawals as they are', () {
      final both = container(liveOverrides(api.api()));
      final wallet = both.read(walletServiceProvider) as LiveWalletService;
      expect(wallet.withdrawals, isTrue);
      final noWithdrawals = container(
        liveOverrides(
          api.api(),
          mode: Backend.of({LiveFeature.profile, LiveFeature.wallet}),
        ),
      );
      expect(
        (noWithdrawals.read(
          walletServiceProvider,
        ) as LiveWalletService).withdrawals,
        isFalse,
      );
    });

    test('preview keeps the demo; a live launch that pauses the wallet '
        'refuses', () async {
      expect(
        container([]).read(walletServiceProvider),
        isA<DemoWalletService>(),
      );
      final paused = container(
        liveOverrides(api.api(), mode: Backend.of({LiveFeature.briefs})),
      ).read(walletServiceProvider);
      expect(paused, isA<PausedWalletService>());
      expect(
        (await paused.withdraw(amountKobo: 1000000, account: _account)).failure,
        WalletFailure.unknown,
      );
      expect(
        (await paused.verifyAccount(
          bankCode: '044',
          accountNumber: '0123',
        )).failure,
        WalletFailure.unknown,
      );
      await expectLater(
        paused.addAccount(_account),
        throwsA(isA<FeaturePaused>()),
      );
      expect(await paused.confirmPin('1234'), isFalse);
      expect(api.requests, isEmpty);
    });
  });
}
