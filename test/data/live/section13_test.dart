import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/app_config.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/live/brief_marks_sync.dart';
import 'package:iqly_mobile/data/live/kept_reads.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/live/live_submit_service.dart';
import 'package:iqly_mobile/data/live/live_wallet_service.dart';
import 'package:iqly_mobile/data/live/submit_queue.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/phone_service.dart';
import 'package:iqly_mobile/data/pin_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/submit_data.dart';
import 'package:iqly_mobile/data/submit_service.dart';
import 'package:iqly_mobile/data/wallet_service.dart';
import 'package:iqly_mobile/features/wallet/wallet_format.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_data_fixtures.dart';

final _now = DateTime(2026, 10, 17, 10);

const _account = SavedBank(
  id: 'ba_1',
  bankCode: '044',
  bankName: 'Access Bank',
  accountNumber: '••6789',
  accountName: 'ADAEZE OKAFOR',
);

Map<String, Object?> _body(http.Request r) =>
    (jsonDecode(r.body) as Map).cast<String, Object?>();

http.Response _refusedWith(
  int status,
  String code,
  Map<String, Object?> details, {
  Map<String, String> headers = const {},
}) => http.Response(
  jsonEncode({
    'success': false,
    'error': {'code': code, 'message': 'No.', 'details': details},
  }),
  status,
  headers: {'content-type': 'application/json', ...headers},
);

AccountLink _link(FakeApi api, MemoryLocalStore store, Outbox outbox) =>
    AccountLink(
      api: api.api(),
      store: store,
      outbox: outbox,
      userId: () => 'u_1',
    );

void main() {
  group('the withdrawal PIN (13.1)', () {
    test('every refusal keeps its reason, tries and wait', () async {
      final api = FakeApi();
      final pins = PinService(api.api());
      final answers = <String, http.Response>{
        '1111': _refusedWith(403, 'PIN_INCORRECT', {'attemptsLeft': 3}),
        '2222': _refusedWith(
          423,
          'PIN_LOCKED',
          {'retryAfterSeconds': 1800, 'lockedUntil': '2026-10-17T10:30:00Z'},
          headers: {'retry-after': '1800'},
        ),
        '3333': _refusedWith(423, 'PIN_RESET_REQUIRED', {}),
        '4444': refused(409, 'PIN_NOT_SET'),
      };
      api.on('POST', '/wallet/pin/verify', (r) {
        final pin = _body(r)['pin'] as String;
        return answers[pin] ?? ok({'verified': true});
      });
      Future<PinRefused> refusal(String pin) async {
        try {
          await pins.verify(pin);
        } on PinRefused catch (refused) {
          return refused;
        }
        fail('$pin was taken');
      }

      final wrong = await refusal('1111');
      expect(wrong.problem, PinProblem.incorrect);
      expect(wrong.attemptsLeft, 3);
      final locked = await refusal('2222');
      expect(locked.problem, PinProblem.locked);
      expect(locked.retryAfter, const Duration(minutes: 30));
      expect((await refusal('3333')).problem, PinProblem.resetRequired);
      expect((await refusal('4444')).problem, PinProblem.notSet);
      await pins.verify('2580');

      for (final request in api.requests) {
        expect(request.url.toString(), isNot(contains('2580')));
        expect(request.headers.values.join(), isNot(contains('2580')));
      }
      api.offline = true;
      expect((await refusal('2580')).problem, PinProblem.offline);
    });

    test('set, change and reset send what the contract names', () async {
      final api = FakeApi();
      final status = {
        'set': true,
        'updatedAt': '2026-10-17T10:00:00Z',
        'locked': false,
        'lockedUntil': null,
        'resetRequired': false,
        'attemptsLeft': 5,
      };
      api.data('POST', '/wallet/pin/code', {
        'sentTo': 'a•••@example.com',
        'expiresAt': '2026-10-17T10:10:00Z',
        'resendAt': '2026-10-17T10:01:00Z',
      });
      api.on('POST', '/wallet/pin', (r) {
        final body = _body(r);
        if (body['password'] == 'wrong') {
          return refused(403, 'PIN_PASSWORD_INCORRECT');
        }
        if (body['code'] == '000000') {
          return _refusedWith(400, 'CODE_INVALID', {'attemptsLeft': 4});
        }
        return ok(status, status: 201);
      });
      api.data('PUT', '/wallet/pin', status);
      api.on(
        'POST',
        '/wallet/pin/reset',
        (r) => _body(r)['code'] == '111111'
            ? refused(400, 'CODE_EXPIRED')
            : ok(status),
      );
      api.data('GET', '/wallet/pin', {...status, 'set': false});
      final pins = PinService(api.api());

      expect((await pins.status()).set, isFalse);
      final sent = await pins.sendCode();
      expect(sent.sentTo, 'a•••@example.com');
      expect(sent.resendAt, isNotNull);
      expect((await pins.create('1234', code: '123456')).set, isTrue);
      expect(_body(api.to('/wallet/pin').last), {
        'pin': '1234',
        'code': '123456',
      });
      await pins.create('1234', password: 'secret');
      expect(_body(api.to('/wallet/pin').last), {
        'pin': '1234',
        'password': 'secret',
      });
      await expectLater(
        pins.create('1234', password: 'wrong'),
        throwsA(
          isA<PinRefused>().having(
            (r) => r.problem,
            'problem',
            PinProblem.passwordIncorrect,
          ),
        ),
      );
      await expectLater(
        pins.create('1234', code: '000000'),
        throwsA(
          isA<PinRefused>()
              .having((r) => r.problem, 'problem', PinProblem.codeInvalid)
              .having((r) => r.attemptsLeft, 'left', 4),
        ),
      );
      await pins.change('1234', '5678');
      expect(_body(api.to('/wallet/pin', method: 'PUT').last), {
        'currentPin': '1234',
        'pin': '5678',
      });
      await expectLater(
        pins.reset('111111', '9999'),
        throwsA(
          isA<PinRefused>().having(
            (r) => r.problem,
            'problem',
            PinProblem.codeExpired,
          ),
        ),
      );
      await pins.reset('222222', '9999');
    });

    test('a withdrawal carries the PIN in its body and names each PIN '
        'refusal', () async {
      final api = FakeApi();
      api.on('POST', '/wallet/withdrawals', (r) {
        final body = _body(r);
        return switch (body['pin']) {
          null => refused(403, 'PIN_REQUIRED'),
          '1111' => _refusedWith(403, 'PIN_INCORRECT', {'attemptsLeft': 2}),
          '2222' => refused(423, 'PIN_LOCKED', 'Locked.', {
            'retry-after': '600',
          }),
          '3333' => refused(423, 'PIN_RESET_REQUIRED'),
          _ when body['amount'] == 50000 => refused(
            400,
            'WITHDRAWAL_BELOW_MINIMUM',
          ),
          _ when body['amount'] == 90000000 => refused(
            400,
            'WITHDRAWAL_ABOVE_MAXIMUM',
          ),
          _ => ok(withdrawalJson({'id': 'w_9'}), status: 201),
        };
      });
      final wallet = LiveWalletService(api.api());
      Future<WithdrawResult> send(String? pin, [int amount = 500000]) =>
          wallet.withdraw(amountKobo: amount, account: _account, pin: pin);

      final none = await send(null);
      expect(none.failure, WalletFailure.pin);
      expect(none.pin!.problem, PinProblem.required);
      final wrong = await send('1111');
      expect(wrong.pin!.problem, PinProblem.incorrect);
      expect(wrong.pin!.attemptsLeft, 2);
      expect(wrong.unsettled, isFalse, reason: 'nothing was made');
      final locked = await send('2222');
      expect(locked.pin!.problem, PinProblem.locked);
      expect(locked.pin!.retryAfter, const Duration(minutes: 10));
      expect((await send('3333')).pin!.problem, PinProblem.resetRequired);
      expect((await send('2580', 50000)).failure, WalletFailure.belowMinimum);
      expect(
        (await send('2580', 90000000)).failure,
        WalletFailure.aboveMaximum,
      );
      final made = await send('2580');
      expect(made.withdrawal!.id, 'w_9');
      expect(_body(api.requests.last)['pin'], '2580');
      expect(api.requests.last.headers.keys, isNot(contains('pin')));
    });
  });

  group('phone codes (13.2)', () {
    test('send, refusals and verify', () async {
      final api = FakeApi();
      api.on('POST', '/me/phone/code', (r) {
        return switch (_body(r)['phone']) {
          '123' => refused(400, 'PHONE_INVALID'),
          '0803 000 0000' => refused(502, 'SMS_SEND_FAILED'),
          '0803 111 1111' => _refusedWith(
            429,
            'RATE_LIMITED',
            {'retryAfterSeconds': 30},
            headers: {'retry-after': '30'},
          ),
          null => refused(409, 'PHONE_ALREADY_VERIFIED'),
          _ => ok({
            'to': '+2348035550101',
            'expiresAt': '2026-10-17T10:10:00Z',
            'resendAt': '2026-10-17T10:00:45Z',
          }),
        };
      });
      api.on(
        'POST',
        '/me/phone/verify',
        (r) => _body(r)['code'] == '123456'
            ? ok({
                'phone': '+2348035550101',
                'verified': true,
                'verifiedAt': '2026-10-17T10:01:00Z',
                'pending': null,
                'resendAt': null,
              })
            : _refusedWith(400, 'CODE_INVALID', {'attemptsLeft': 4}),
      );
      final phones = PhoneService(api.api());
      Future<PhoneRefused> refusal(Future<Object?> call) async {
        try {
          await call;
        } on PhoneRefused catch (refused) {
          return refused;
        }
        fail('taken');
      }

      expect(
        (await refusal(phones.sendCode('123'))).problem,
        PhoneProblem.invalid,
      );
      expect(
        (await refusal(phones.sendCode('0803 000 0000'))).problem,
        PhoneProblem.sendFailed,
      );
      final limited = await refusal(phones.sendCode('0803 111 1111'));
      expect(limited.problem, PhoneProblem.rateLimited);
      expect(limited.retryAfter, const Duration(seconds: 30));
      expect(
        (await refusal(phones.sendCode())).problem,
        PhoneProblem.alreadyVerified,
      );
      expect(api.requests.last.body, '{}', reason: 'an empty body');
      final sent = await phones.sendCode('0803 555 0101');
      expect(sent.to, '+2348035550101');
      expect(sent.resendAt, DateTime.utc(2026, 10, 17, 10, 0, 45).toLocal());
      final wrong = await refusal(phones.verify('000000'));
      expect(wrong.problem, PhoneProblem.codeInvalid);
      expect(wrong.attemptsLeft, 4);
      final status = await phones.verify('123456');
      expect(status.verified, isTrue);
      expect(status.phone, '+2348035550101');
    });

    test('an API without SMS answers 503 SMS_NOT_CONFIGURED', () async {
      final api = FakeApi();
      api.on(
        'POST',
        '/me/phone/code',
        (_) => refused(503, 'SMS_NOT_CONFIGURED'),
      );
      await expectLater(
        PhoneService(api.api()).sendCode('0803 555 0101'),
        throwsA(
          isA<PhoneRefused>().having(
            (r) => r.problem,
            'problem',
            PhoneProblem.notConfigured,
          ),
        ),
      );
    });
  });

  group('ETags (13.5)', () {
    test('a second read sends If-None-Match and a 304 answers the kept '
        'body, for the account that read it only', () async {
      final api = FakeApi();
      var reads = 0;
      api.on('GET', '/wallet', (r) {
        reads++;
        if (r.headers['if-none-match'] == 'W/"t1"') {
          return http.Response('', 304, headers: {'etag': 'W/"t1"'});
        }
        return http.Response(
          jsonEncode({'success': true, 'data': walletJson()}),
          200,
          headers: {'content-type': 'application/json', 'etag': 'W/"t1"'},
        );
      });
      final store = MemoryLocalStore(clock: () => _now);
      final client = api.api();
      final ada = StoreEtags(store, 'u_1');

      final first = await client.get('/wallet', etags: ada);
      expect(api.requests.last.headers['if-none-match'], isNull);
      final second = await client.get('/wallet', etags: ada);
      expect(api.requests.last.headers['if-none-match'], 'W/"t1"');
      expect(second.status, 200);
      expect(second.data, first.data);

      await client.get('/wallet', etags: StoreEtags(store, 'u_2'));
      expect(
        api.requests.last.headers['if-none-match'],
        isNull,
        reason: 'one person’s tag never answers another',
      );
      await client.get('/wallet');
      expect(api.requests.last.headers['if-none-match'], isNull);
      expect(reads, 4);
    });

    test('the live repository reads conditionally only while etags is '
        'live', () async {
      for (final live in [true, false]) {
        final api = FakeApi();
        api.on(
          'GET',
          '/wallet',
          (r) => r.headers['if-none-match'] != null
              ? http.Response('', 304)
              : http.Response(
                  jsonEncode({'success': true, 'data': walletJson()}),
                  200,
                  headers: {
                    'content-type': 'application/json',
                    'etag': 'W/"w"',
                  },
                ),
        );
        final repo = LiveRepository(
          api: api.api(),
          store: MemoryLocalStore(clock: () => _now),
          mode: Backend.of({...firstFeatures, if (live) LiveFeature.etags}),
          demo: DemoRepository(DemoData(now: _now)),
          userId: 'u_1',
        );
        final first = await repo.walletTotals();
        final second = await repo.walletTotals();
        expect(second!.withdrawableKobo, first!.withdrawableKobo);
        expect(
          api.requests.last.headers['if-none-match'],
          live ? 'W/"w"' : isNull,
        );
      }
    });
  });

  group('GET /config (13.6)', () {
    Future<ProviderContainer> container(FakeApi api, Backend mode) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...liveOverrides(api.api(), mode: mode),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(() => AppConfig.current = AppConfig.defaults);
      return c;
    }

    test('live, its numbers replace the shipped ones and are kept for the '
        'next launch', () async {
      final api = FakeApi();
      api.data('GET', '/config', {
        'contract': 1,
        'support': {'email': 'help@iqly.net', 'messageMaxChars': 800},
        'referrals': {'rewardKobo': 100000},
        'withdrawals': {'minimumKobo': 200000, 'maximumKobo': 5000000},
        'submissions': {'maxFiles': 3},
        'activations': {'proofVideoMaxSeconds': 90},
        'phone': {'resendAfterSeconds': 60},
        'closeReminders': {
          'defaultOffsetsMinutes': [60, 1440],
        },
      });
      final c = await container(
        api,
        Backend.of({...firstFeatures, LiveFeature.config}),
      );
      expect(c.read(appConfigProvider).withdrawalMinimumKobo, 100000);
      await c.read(appConfigProvider.notifier).refresh();
      final config = c.read(appConfigProvider);
      expect(config.supportEmail, 'help@iqly.net');
      expect(minimumWithdrawalKobo, 200000);
      expect(maximumWithdrawalKobo, 5000000);
      expect(aboveMaximum(5000001), isTrue);
      expect(belowMinimum(150000, 900000), isTrue);
      expect(referralReward(), '₦1,000');
      expect(SubmitLimits.files, 3);
      expect(SubmitLimits.fileBytes, 10 * 1024 * 1024);
      expect(config.closeReminderOffsets, [60, 1440]);
      expect(config.phoneResendAfterSeconds, 60);

      c.invalidate(appConfigProvider);
      AppConfig.current = AppConfig.defaults;
      expect(c.read(appConfigProvider).supportEmail, 'help@iqly.net');
    });

    test('off, nothing is asked and the shipped numbers stand', () async {
      final api = FakeApi();
      final c = await container(api, allLive);
      await c.read(appConfigProvider.notifier).refresh();
      expect(api.to('/config'), isEmpty);
      expect(c.read(appConfigProvider).withdrawalMinimumKobo, 100000);
      expect(minimumWithdrawalKobo, 100000);
      expect(referralReward(), '₦500');
    });
  });

  group('saved briefs and reminders (13.3)', () {
    test('a pull lays unsent changes over the API list: removals made '
        'elsewhere win, changes not yet sent win until they go', () async {
      final api = FakeApi();
      api.data('GET', '/me/saved-briefs', {
        'items': [
          {'challengeId': 'c_2', 'savedAt': '2026-10-16T10:00:00Z'},
          {'challengeId': 'c_1', 'savedAt': '2026-10-15T10:00:00Z'},
        ],
      });
      final puts = <String>[];
      api.on('PUT', '/me/saved-briefs/c_3', (r) {
        puts.add(r.headers['idempotency-key']!);
        return ok({'challengeId': 'c_3', 'savedAt': '2026-10-17T10:00:00Z'});
      });
      api.on('DELETE', '/me/saved-briefs/c_1', (_) => http.Response('', 204));
      final store = MemoryLocalStore(clock: () => _now);
      final outbox = Outbox(store, clock: () => _now);
      final sync = BriefMarksSync(_link(api, store, outbox), BriefMark.saved);

      expect(await sync.pull(), ['c_2', 'c_1']);
      await sync.set('c_3', true);
      await sync.set('c_1', false);
      await sync.set('c_4', true);
      await sync.set('c_4', false);
      expect(await sync.pull(), ['c_3', 'c_2']);
      expect(
        (await store.outbox('u_1'))
            .where((i) => i.payload['challengeId'] == 'c_4'),
        hasLength(1),
        reason: 'marking and unmarking before either goes folds',
      );

      registerBriefMarkWrites(outbox, api.api(), live: (_) => true);
      api.on('DELETE', '/me/saved-briefs/c_4', (_) => http.Response('', 204));
      await outbox.start('u_1');
      expect(puts, hasLength(1));
      expect(api.to('/me/saved-briefs/c_1', method: 'DELETE'), hasLength(1));
      expect(await store.outbox('u_1'), isEmpty);
    });

    test('a reminder sends its minutes before close; a refusal pulls the '
        'list back', () async {
      final api = FakeApi();
      api.on(
        'PUT',
        '/me/close-reminders/c_1',
        (r) => ok({'challengeId': 'c_1', ..._body(r)}),
      );
      api.on(
        'PUT',
        '/me/close-reminders/c_9',
        (_) => refused(409, 'CLOSE_REMINDER_BRIEF_CLOSED'),
      );
      final store = MemoryLocalStore(clock: () => _now);
      final outbox = Outbox(store, clock: () => _now);
      final refusedMarks = <BriefMark>[];
      registerBriefMarkWrites(
        outbox,
        api.api(),
        live: (_) => true,
        onRefused: refusedMarks.add,
      );
      final sync = BriefMarksSync(
        _link(api, store, outbox),
        BriefMark.reminder,
      );
      await sync.set('c_1', true, offsets: [60]);
      await sync.set('c_9', true, offsets: [60]);
      await outbox.start('u_1');
      expect(_body(api.to('/me/close-reminders/c_1').single), {
        'offsetsMinutes': [60],
      });
      expect(refusedMarks, [BriefMark.reminder]);
    });

    test('off, nothing registers and the lists stay on the phone', () async {
      final api = FakeApi();
      final store = MemoryLocalStore(clock: () => _now);
      final outbox = Outbox(store, clock: () => _now);
      registerBriefMarkWrites(outbox, api.api(), live: (_) => false);
      await store.enqueue(
        'u_1',
        kind: BriefMark.saved.put,
        payload: {'challengeId': 'c_1'},
      );
      await outbox.start('u_1');
      expect(api.requests, isEmpty);
      expect(await store.outbox('u_1'), hasLength(1), reason: 'kept');
    });
  });

  group('uploads and the queued send (13.4)', () {
    test('each upload refusal keeps its reason', () async {
      final api = FakeApi();
      final answers = {
        'a.txt': refused(415, 'FILE_TYPE_NOT_ALLOWED'),
        'big.png': refused(413, 'FILE_TOO_LARGE'),
        'many.png': _refusedWith(409, 'SUBMISSION_UPLOADS_LIMIT', {
          'maxUploads': 20,
          'maxBytes': 209715200,
        }),
        'fast.png': refused(429, 'RATE_LIMITED'),
      };
      api.on('POST', '/submissions/uploads', (r) {
        final name = RegExp(r'filename="([^"]+)"').firstMatch(r.body)![1]!;
        return answers[name] ??
            ok({
              'id': 'up_1',
              'kind': 'image',
              'expiresAt': '2026-10-18T10:00:00Z',
            }, status: 201);
      });
      api.on(
        'DELETE',
        '/submissions/uploads/up_1',
        (_) => http.Response('', 204),
      );
      final uploads = SubmissionUploads(api.api());
      AttachmentFile file(String name) =>
          AttachmentFile(name: name, bytes: 3, read: () async => [1, 2, 3]);
      Future<UploadProblem> problem(String name) async {
        try {
          await uploads.upload(file(name), briefId: 'c_1');
        } on UploadRefused catch (refused) {
          return refused.problem;
        }
        fail('$name was taken');
      }

      expect(await problem('a.txt'), UploadProblem.fileType);
      expect(await problem('big.png'), UploadProblem.tooLarge);
      expect(await problem('many.png'), UploadProblem.limit);
      expect(await problem('fast.png'), UploadProblem.rateLimited);
      final progress = <double>[];
      final up = await uploads.upload(
        file('kiosk.png'),
        briefId: 'c_1',
        onProgress: progress.add,
      );
      expect(up.id, 'up_1');
      expect(progress.last, 1);
      expect(api.requests.last.body, contains('name="challengeId"'));
      await uploads.drop('up_1');
      expect(
        api.to('/submissions/uploads/up_1', method: 'DELETE'),
        hasLength(1),
      );
      api.offline = true;
      expect(await problem('kiosk.png'), UploadProblem.offline);
    });

    test('offline, a send naming its uploads is queued; back online it '
        'goes once, under one Idempotency-Key', () async {
      final api = FakeApi();
      final made = <String, Map<String, Object?>>{};
      api.on('POST', '/submissions/challenges/c_1', (r) {
        final key = r.headers['idempotency-key']!;
        final known = made.containsKey(key);
        final row = made[key] ??= {
          ...submissionJson({
            'id': 's_${made.length + 1}',
            'challengeId': 'c_1',
          }),
          'entries': 13,
        };
        return ok(row, status: known ? 200 : 201);
      });
      api.data('GET', '/challenges/c_1', challengeJson());
      final store = MemoryLocalStore(clock: () => _now);
      final outbox = Outbox(store, clock: () => _now);
      final sent = <String>[];
      registerSubmitWrites(
        outbox,
        api.api(),
        store,
        live: true,
        onSent: (user, brief) => sent.add('$user $brief'),
      );
      await outbox.start('u_1');
      final queue = SubmitQueue(
        _link(api, store, outbox),
        wait: const Duration(seconds: 5),
      );
      final service = LiveSubmitService(api.api(), queue: queue);
      await service.open('c_1');
      api.offline = true;

      final result = await service.submit(
        const SubmitRequest(
          briefId: 'c_1',
          title: 'Sunday is data day',
          answer: 'Give a bonus bundle on Sundays, every week.',
          answers: {
            'q_lang': ['English'],
            'q_where': ['USSD', 'Agent'],
            'q_why': ['Payday'],
          },
          uploadIds: ['up_1', 'up_2'],
        ),
      );
      expect(result.queued, isTrue);
      expect(result.receipt, isNull);
      expect(made, isEmpty);
      expect(await store.outbox('u_1'), hasLength(1));

      api.offline = false;
      await outbox.networkBack();
      expect(made, hasLength(1));
      expect(sent, ['u_1 c_1']);
      final request = api.to('/submissions/challenges/c_1').last;
      expect(request.body, contains('["up_1","up_2"]'));
      expect(request.body, contains('"q_where":["USSD","Agent"]'));
      expect(request.body, isNot(contains('filename=')));
      expect(
        api
            .to('/submissions/challenges/c_1')
            .map((r) => r.headers['idempotency-key'])
            .toSet(),
        hasLength(1),
      );
    });

    test('online, the screen hears the answer; each refusal maps', () async {
      final api = FakeApi();
      final codes = [
        refused(404, 'SUBMISSION_UPLOAD_NOT_FOUND'),
        refused(409, 'SUBMISSION_UPLOAD_IN_USE'),
        refused(409, 'SUBMISSION_CAP_REACHED'),
        _refusedWith(409, 'SUBMISSION_DUPLICATE', {'submissionId': 's_7'}),
        ok({
          ...submissionJson({'id': 's_8'}),
          'entries': 14,
        }, status: 201),
      ];
      api.on('POST', '/submissions/challenges/c_1', (_) => codes.removeAt(0));
      api.data('GET', '/challenges/c_1', challengeJson());
      final store = MemoryLocalStore(clock: () => _now);
      final outbox = Outbox(store, clock: () => _now);
      registerSubmitWrites(outbox, api.api(), store, live: true);
      await outbox.start('u_1');
      final service = LiveSubmitService(
        api.api(),
        queue: SubmitQueue(_link(api, store, outbox)),
      );
      await service.open('c_1');
      Future<SubmitResult> send() => service.submit(
        const SubmitRequest(
          briefId: 'c_1',
          title: 'Sunday is data day',
          answer: 'Give a bonus bundle on Sundays, every week.',
          uploadIds: ['up_1'],
        ),
      );

      expect((await send()).failure, SubmitFailure.uploadsGone);
      expect((await send()).failure, SubmitFailure.uploadsGone);
      final full = await send();
      expect(full.block, SubmitBlock.full);
      final twice = await send();
      expect(twice.block, SubmitBlock.alreadySubmitted);
      final receipt = (await send()).receipt!;
      expect(receipt.submission.id, 's_8');
      expect(receipt.entries, 14);
    });

    test('a send without uploads keeps the inline path', () async {
      final api = FakeApi();
      api.data('GET', '/challenges/c_1', challengeJson());
      api.data('POST', '/submissions/challenges/c_1', {
        ...submissionJson({'id': 's_1'}),
        'entries': 2,
      }, status: 201);
      final service = LiveSubmitService(api.api());
      await service.open('c_1');
      final result = await service.submit(
        SubmitRequest(
          briefId: 'c_1',
          title: 'Sunday is data day',
          answer: 'Give a bonus bundle on Sundays, every week.',
          files: [
            AttachmentFile(
              name: 'kiosk.png',
              bytes: 3,
              read: () async => [1, 2, 3],
            ),
          ],
        ),
      );
      expect(result.receipt, isNotNull);
      expect(
        api.to('/submissions/challenges/c_1').single.headers['content-type'],
        startsWith('multipart/form-data'),
      );
    });
  });
}
