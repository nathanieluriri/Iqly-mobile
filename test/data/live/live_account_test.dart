import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/live_api.dart';

AccountLink _link(FakeApi api, {String? userId = 'u_1', LocalStore? store}) {
  final kept = store ?? MemoryLocalStore();
  return AccountLink(
    api: api.client,
    store: kept,
    outbox: Outbox(kept),
    userId: () => userId,
  );
}

Future<ProviderContainer> _container(
  FakeApi api, {
  Backend? mode,
  Map<String, Object> prefs = const {'session.signedIn': true},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final shared = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(shared),
      ...liveOverrides(api, mode: mode),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('the API\'s values', () {
    test('a date of birth is the calendar day it names, both ways', () {
      expect(apiDate('2001-04-09'), DateTime(2001, 4, 9));
      expect(apiDay(DateTime(2001, 4, 9)), '2001-04-09');
      expect(apiDate('2001-02-30'), isNull);
      expect(apiDate('9 April'), isNull);
      expect(apiDate(null), isNull);
    });

    test('times arrive in UTC and read in the phone\'s zone', () {
      final at = apiTime('2026-09-01T10:00:00.000Z')!;
      expect(at.isUtc, isFalse);
      expect(at.toUtc(), DateTime.utc(2026, 9, 1, 10));
      expect(apiTime('soon'), isNull);
    });
  });

  group('GET /me', () {
    test('maps the contract\'s answer onto the account and the user', () {
      final me = Me.fromJson(meJson());
      expect(me.id, 'u_1');
      expect(me.name, 'Ada Obi');
      expect(me.email, 'ada@example.com');
      expect(me.memberSince!.toUtc(), DateTime.utc(2026, 9, 1, 10));
      expect(me.closing, isFalse);
      expect(me.closesAt, isNull);
      expect(
        me.profile!.onboardingCompletedAt!.toUtc(),
        DateTime.utc(2026, 9, 1, 10, 5),
      );

      final user = me.toUser();
      expect(user.firstName, 'Ada');
      expect(user.lastName, 'Obi');
      expect(user.email, 'ada@example.com');
      expect(user.state, 'Lagos');
      expect(user.city, 'Yaba');
      expect(user.university, 'University of Lagos');
      expect(user.occupation, 'student');
      expect(user.education, 'hnd_bsc');
      expect(user.interests, ['Finance & fintech', 'Marketing & advertising']);
    });

    test('the name splits at its first space only', () {
      final me = Me.fromJson({...meJson(), 'name': '  Ada  Chioma   Obi '});
      expect(me.toUser().firstName, 'Ada');
      expect(me.toUser().lastName, 'Chioma Obi');
      final one = Me.fromJson({...meJson(), 'name': 'Ada'}).toUser();
      expect((one.firstName, one.lastName), ('Ada', ''));
    });

    test('closing carries its date; any other status reads as active', () {
      final closing = Me.fromJson(
        meJson(status: 'closing', closesAt: '2026-10-31T10:00:00.000Z'),
      );
      expect(closing.closing, isTrue);
      expect(closing.closesAt!.toUtc(), DateTime.utc(2026, 10, 31, 10));
      expect(Me.fromJson(meJson(status: 'suspended')).closing, isFalse);
    });

    test('no profile yet, and values the app does not know, read as '
        'unanswered', () {
      final bare = Me.fromJson(meJson(profile: null)).toUser();
      expect(bare.state, '');
      expect(bare.interests, isEmpty);
      expect(bare.occupation, isNull);

      final odd = Me.fromJson(
        meJson(
          profile: {
            ...profileJson(),
            'occupations': ['astronaut', 'employed'],
            'education': 'phd',
            'interests': ['space', 'education'],
            'gender': 'robot',
          },
        ),
      );
      expect(odd.toUser().occupation, 'employed');
      expect(odd.toUser().education, isNull);
      expect(odd.toUser().interests, ['Education']);
      expect(odd.profile!.gender, isNull);
    });

    test('meProvider asks once signed in and keeps the session\'s account id '
        'and name in step', () async {
      final api = FakeApi({'GET /me': (_) => answer(meJson())});
      final container = await _container(
        api,
        prefs: {'session.signedIn': true, 'session.name': 'Ada'},
      );
      final me = await container.read(meProvider.future);
      expect(me!.id, 'u_1');
      final session = container.read(sessionProvider);
      expect(session.userId, 'u_1');
      expect(session.name, 'Ada Obi');
      expect(session.firstName, 'Ada');
    });

    test('meProvider answers the kept copy offline', () async {
      final api = FakeApi({'GET /me': (_) => answer(meJson())});
      final container = await _container(api);
      await container.read(meProvider.future);
      api.offline = true;
      container.invalidate(meProvider);
      final me = await container.read(meProvider.future);
      expect(me!.email, 'ada@example.com');
    });

    test('meProvider is null in the preview and signed out, and asks '
        'nothing', () async {
      final api = FakeApi({'GET /me': (_) => answer(meJson())});
      final preview = await _container(api, mode: Backend.preview);
      expect(await preview.read(meProvider.future), isNull);
      final signedOut = await _container(api, prefs: const {});
      expect(await signedOut.read(meProvider.future), isNull);
      expect(api.calls, isEmpty);
    });
  });

  group('close and restore', () {
    test('close sends {confirm: DELETE} online, never queued', () async {
      final api = FakeApi({
        'POST /me/account/close': (_) => answer({
          'status': 'closing',
          'closesAt': '2026-11-16T09:00:00.000Z',
        }),
      });
      final link = _link(api);
      await LiveAccount(link).close();
      expect(api.to('POST /me/account/close').single.body, {
        'confirm': 'DELETE',
      });
      expect(await link.store.outbox('u_1'), isEmpty);
    });

    test('a balance or a withdrawal in flight refuses the close, and the '
        'session stays', () async {
      for (final code in ['ACCOUNT_HAS_BALANCE', 'WITHDRAWAL_IN_FLIGHT']) {
        final api = FakeApi({
          'POST /me/account/close': (_) => refusal(409, code),
        });
        await expectLater(
          LiveAccount(_link(api)).close(),
          throwsA(
            isA<ApiRefused>()
                .having((r) => r.status, 'status', 409)
                .having((r) => r.code, 'code', code),
          ),
        );
        expect(await api.tokens.read(), 'signed.token');
      }
    });

    test('restore reopens, and an account already active counts as '
        'restored', () async {
      final api = FakeApi({
        'POST /me/account/restore': (_) => answer({'status': 'active'}),
      });
      await LiveAccount(_link(api)).restore();
      api.routes['POST /me/account/restore'] = (_) =>
          refusal(409, 'ACCOUNT_NOT_CLOSING');
      await LiveAccount(_link(api)).restore();
      expect(api.to('POST /me/account/restore'), hasLength(2));
    });

    test('a restore that does not go through throws', () async {
      final api = FakeApi({
        'POST /me/account/restore': (_) => refusal(500, 'HTTP_ERROR'),
      });
      await expectLater(
        LiveAccount(_link(api)).restore(),
        throwsA(isA<ApiRefused>()),
      );
      api.offline = true;
      await expectLater(
        LiveAccount(_link(api)).restore(),
        throwsA(isA<ApiUnreachable>()),
      );
    });
  });

  group('queued writes', () {
    test('go with the item\'s id as the Idempotency-Key, and an answer that '
        'is the record is kept', () async {
      final store = MemoryLocalStore();
      final api = FakeApi({
        'PATCH /profiles/contributors/me': (_) => answer(profileJson()),
      });
      final outbox = Outbox(store);
      registerAccountWrites(outbox, api.client, store);
      await outbox.start('u_1');
      final item = await outbox.enqueue(
        'u_1',
        kind: AccountWrite.profile.kind,
        payload: {'city': 'Yaba'},
      );
      await outbox.kick();
      final sent = api.to('PATCH /profiles/contributors/me').single;
      expect(sent.headers['idempotency-key'], item.id);
      expect(sent.body, {'city': 'Yaba'});
      expect((await store.outboxItem(item.id))!.status, OutboxStatus.done);
      final kept = await store.readCache('u_1', AccountKeys.profile);
      expect((kept!.json as Map)['city'], 'Yaba');
    });

    test('a refusal fails the item and is heard; no answer sends again '
        'later', () async {
      final store = MemoryLocalStore();
      final api = FakeApi({
        'POST /me/onboarding': (_) => refusal(403, 'UNDER_AGE'),
      });
      final outbox = Outbox(store);
      final heard = <(AccountWrite, String)>[];
      registerAccountWrites(
        outbox,
        api.client,
        store,
        onFailed: (item, write, code) => heard.add((write, code)),
      );
      await outbox.start('u_1');
      final refused = await outbox.enqueue(
        'u_1',
        kind: AccountWrite.onboarding.kind,
        payload: {'skipped': false},
      );
      await outbox.kick();
      final failed = await store.outboxItem(refused.id);
      expect(failed!.status, OutboxStatus.failed);
      expect(failed.lastErrorCode, 'UNDER_AGE');
      expect(heard, [(AccountWrite.onboarding, 'UNDER_AGE')]);

      api.offline = true;
      final waiting = await outbox.enqueue(
        'u_1',
        kind: AccountWrite.seen.kind,
        payload: {'until': '2026-10-17T09:00:00.000Z'},
      );
      await outbox.kick();
      final retried = await store.outboxItem(waiting.id);
      expect(retried!.status, OutboxStatus.pending);
      expect(retried.lastErrorCode, OutboxCodes.network);
      await outbox.stop();
    });

    test('with no account id a write goes straight to the API', () async {
      final api = FakeApi({
        'PUT /me/notification-preferences': (call) => answer(call.body),
      });
      final link = _link(api, userId: null);
      await link.queue(AccountWrite.preferences, {'polls': true});
      expect(api.to('PUT /me/notification-preferences').single.body, {
        'polls': true,
      });
      api.routes['PUT /me/notification-preferences'] = (_) =>
          refusal(403, 'ACCOUNT_CLOSING');
      await expectLater(
        link.queue(AccountWrite.preferences, {'polls': false}),
        throwsA(isA<ApiRefused>()),
      );
    });
  });
}
