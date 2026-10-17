import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/live/live_wallet_service.dart';
import 'package:iqly_mobile/data/live/mappers.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/wallet_service.dart';

import 'live_data_fixtures.dart';

const _account = SavedBank(
  bankCode: '044',
  bankName: 'Access Bank',
  accountName: 'ADAEZE OKAFOR',
  accountNumber: '6789',
);

void main() {
  late FakeApi api;
  late DemoWalletService demo;
  late LiveWalletService service;

  setUp(() {
    api = FakeApi();
    demo = DemoWalletService(delay: Duration.zero, payoutStep: null);
    service = LiveWalletService(api.api(), demo: demo);
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
      expect(demo.defaults, isEmpty);
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
      expect(demo.requests, isEmpty);
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

    test('a different amount is a new request', () async {
      api.offline = true;
      await service.withdraw(amountKobo: 1000000, account: _account);
      await service.withdraw(amountKobo: 500000, account: _account);
      expect(
        api.requests.first.headers['idempotency-key'],
        isNot(api.requests.last.headers['idempotency-key']),
      );
    });

    test('every refusal reads as unknown, no connection as offline', () async {
      for (final (status, code) in [
        (409, 'WALLET_INSUFFICIENT_BALANCE'),
        (409, 'PROFILE_INCOMPLETE'),
        (403, 'UNDER_AGE'),
        (400, 'WITHDRAWAL_BELOW_MINIMUM'),
        (409, 'WITHDRAWAL_NO_BANK_ACCOUNT'),
        (403, 'ACCOUNT_CLOSING'),
      ]) {
        api.on('POST', '/wallet/withdrawals', (_) => refused(status, code));
        final result = await service.withdraw(
          amountKobo: 1000000,
          account: _account,
        );
        expect(result.failure, WalletFailure.unknown, reason: code);
      }
      api.on(
        'POST',
        '/wallet/withdrawals',
        (_) => refused(429, 'RATE_LIMITED', 'Slow down', {'retry-after': '30'}),
      );
      expect(
        (await service.withdraw(
          amountKobo: 1000000,
          account: _account,
        )).failure,
        WalletFailure.unknown,
      );
      api.offline = true;
      expect(
        (await service.withdraw(
          amountKobo: 1000000,
          account: _account,
        )).failure,
        WalletFailure.offline,
      );
    });

    test('with withdrawals on preview data the demo takes them', () async {
      final wallet = LiveWalletService(
        api.api(),
        demo: demo,
        withdrawals: false,
      );
      final result = await wallet.withdraw(
        amountKobo: 1000000,
        account: _account,
      );
      expect(result.ok, isTrue);
      expect(demo.requests.single.amountKobo, 1000000);
      expect(api.requests, isEmpty);
      expect(await wallet.confirmPin('1234'), isTrue);
      expect(demo.pins, ['1234']);
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
    ProviderContainer container(List<Override> overrides) {
      final c = ProviderContainer(overrides: overrides);
      addTearDown(c.dispose);
      return c;
    }

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

    test('preview, or the wallet on preview, keeps the demo', () {
      expect(
        container([]).read(walletServiceProvider),
        isA<DemoWalletService>(),
      );
      expect(
        container(
          liveOverrides(api.api(), mode: Backend.of({LiveFeature.briefs})),
        ).read(walletServiceProvider),
        isA<DemoWalletService>(),
      );
    });
  });
}
