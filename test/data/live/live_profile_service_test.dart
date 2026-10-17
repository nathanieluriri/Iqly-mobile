import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_profile_service.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/live_api.dart';

const _profilePath = 'GET /profiles/contributors/me';
const _patch = 'PATCH /profiles/contributors/me';
const _prefsGet = 'GET /me/notification-preferences';
const _prefsPut = 'PUT /me/notification-preferences';

/// The contract's example map (3.3).
const _preferences = {
  'closingSoon': true,
  'results': true,
  'payouts': true,
  'newBriefs': true,
  'polls': false,
};

class _Service {
  _Service(this.api, {bool accountLive = true}) {
    link = AccountLink(
      api: api.client,
      store: store,
      outbox: outbox,
      userId: () => 'u_1',
    );
    service = LiveProfileService(
      link,
      account: accountLive ? LiveAccount(link) : null,
      preview: DemoProfileService(delay: Duration.zero),
    );
    registerAccountWrites(outbox, api.client, store);
  }

  final FakeApi api;
  final LocalStore store = MemoryLocalStore();
  late final Outbox outbox = Outbox(store);
  late final AccountLink link;
  late final LiveProfileService service;

  Future<List<OutboxItem>> queued() => store.outbox('u_1');
}

void main() {
  test('the contributor profile maps onto Your details\' account fields', () {
    final profile = ContributorProfile.fromJson(profileJson());
    expect(
      profile.details,
      AccountDetails(
        phone: '+2348012345678',
        dateOfBirth: DateTime(2001, 4, 9),
        gender: 'female',
        stateOfOrigin: 'Anambra',
      ),
    );
    expect(profile.stateOfResidence, 'Lagos');
    expect(profile.occupations, ['student']);
    expect(profile.interests, ['finance_fintech', 'marketing_advertising']);
    final bare = ContributorProfile.fromJson({
      ...profileJson(phone: null, dateOfBirth: null),
      'gender': 'unknown',
      'sector': 'mining',
    });
    expect(bare.details, const AccountDetails(stateOfOrigin: 'Anambra'));
    expect(bare.sector, isNull);
  });

  group('accountDetails', () {
    test('reads the server copy and keeps it for a read offline', () async {
      final s = _Service(FakeApi({_profilePath: (_) => answer(profileJson())}));
      expect((await s.service.accountDetails()).phone, '+2348012345678');
      s.api.offline = true;
      expect((await s.service.accountDetails()).stateOfOrigin, 'Anambra');
    });

    test('offline with nothing kept throws, so the device copy can stand '
        'in', () async {
      final s = _Service(FakeApi())..api.offline = true;
      await expectLater(
        s.service.accountDetails(),
        throwsA(isA<ApiUnreachable>()),
      );
    });

    test('a new account without a profile has no details yet', () async {
      final s = _Service(
        FakeApi({_profilePath: (_) => refusal(404, 'NOT_FOUND')}),
      );
      expect(await s.service.accountDetails(), const AccountDetails());
    });

    test('an edit still to go is laid over the server copy', () async {
      final s = _Service(FakeApi({_profilePath: (_) => answer(profileJson())}));
      s.api.offline = true;
      final before = AccountDetails(
        phone: '+2348012345678',
        dateOfBirth: DateTime(2001, 4, 9),
      );
      await s.service.saveDetails(
        before.copyWith(phone: '+2348035554410'),
        const OnboardingProfile(),
        before: before,
        answersBefore: const OnboardingProfile(),
      );
      s.api.offline = false;
      final details = await s.service.accountDetails();
      expect(details.phone, '+2348035554410');
      expect(details.dateOfBirth, DateTime(2001, 4, 9));
    });
  });

  group('saveDetails', () {
    test('queues a PATCH of the changed fields only', () async {
      final s = _Service(FakeApi());
      final details = AccountDetails(
        phone: '+2348012345678',
        dateOfBirth: DateTime(2001, 4, 9),
      );
      const answers = OnboardingProfile(
        occupation: 'student',
        state: 'Lagos',
        city: 'Yaba',
        interests: ['finance_fintech', 'other'],
        otherInterest: 'Football',
      );
      await s.service.saveDetails(
        details,
        answers.copyWith(city: 'Ikeja', otherInterest: 'Chess'),
        before: details,
        answersBefore: answers,
      );
      await s.service.saveDetails(
        details.copyWith(dateOfBirth: DateTime(1999, 12, 31)),
        answers,
        before: details,
        answersBefore: answers,
      );
      final item = (await s.queued()).single;
      expect(item.kind, AccountWrite.profile.kind);
      expect(item.coalesceKey, 'profile:patch');
      expect(item.payload, {
        'city': 'Ikeja',
        'interestOther': 'Chess',
        'dateOfBirth': '1999-12-31',
      });
    });

    test('fields merge as they fold, the latest of each winning, and go as '
        'one PATCH', () async {
      final s = _Service(FakeApi({_patch: (call) => answer(call.body)}));
      const answers = OnboardingProfile(state: 'Lagos', city: 'Yaba');
      const details = AccountDetails(phone: '+2348012345678');
      Future<void> save(AccountDetails next, OnboardingProfile nextAnswers) =>
          s.service.saveDetails(
            next,
            nextAnswers,
            before: details,
            answersBefore: answers,
          );
      await save(details.copyWith(phone: '+2348035554410'), answers);
      await save(details, answers.copyWith(state: 'Oyo', city: ''));
      await save(details.copyWith(phone: '+2348099999999'), answers);
      final item = (await s.queued()).single;
      expect(item.payload, {
        'phone': '+2348099999999',
        'stateOfResidence': 'Oyo',
        'city': null,
      });

      await s.outbox.start('u_1');
      final sent = s.api.to(_patch).single;
      expect(sent.body, {
        'phone': '+2348099999999',
        'stateOfResidence': 'Oyo',
        'city': null,
      });
      expect(sent.headers['idempotency-key'], item.id);
    });

    test('nothing changed queues nothing', () async {
      final s = _Service(FakeApi());
      const details = AccountDetails(phone: '+2348012345678');
      const answers = OnboardingProfile(state: 'Lagos');
      await s.service.saveDetails(
        details,
        answers,
        before: details,
        answersBefore: answers,
      );
      expect(await s.queued(), isEmpty);
    });

    test('the PATCH fields follow the contract\'s names and values', () {
      expect(
        profileFields(
          AccountDetails(
            phone: '',
            dateOfBirth: DateTime(2001, 4, 9),
            gender: 'female',
            stateOfOrigin: 'Anambra',
          ),
          const OnboardingProfile(
            occupation: 'employed',
            sector: 'other',
            otherSector: ' Event planning ',
            state: 'Lagos',
            city: 'Yaba',
            interests: ['education'],
          ),
        ),
        {
          'phone': null,
          'dateOfBirth': '2001-04-09',
          'gender': 'female',
          'stateOfOrigin': 'Anambra',
          'stateOfResidence': 'Lagos',
          'city': 'Yaba',
          'occupations': ['employed'],
          'education': null,
          'university': null,
          'sector': 'other',
          'sectorOther': 'Event planning',
          'interests': ['education'],
          'interestOther': null,
        },
      );
    });
  });

  group('notification preferences', () {
    test('read the API\'s map, a missing switch at its default', () async {
      final s = _Service(
        FakeApi({
          _prefsGet: (_) => answer({..._preferences}..remove('newBriefs')),
        }),
      );
      expect(await s.service.notificationPreferences(), {
        NotificationTopic.closingSoon: true,
        NotificationTopic.results: true,
        NotificationTopic.payouts: true,
        NotificationTopic.newBriefs: true,
        NotificationTopic.polls: false,
      });
    });

    test('a flip queues the whole map as one PUT, the latest replacing any '
        'still waiting, and shows on the next read', () async {
      final s = _Service(
        FakeApi({
          _prefsGet: (_) => answer(_preferences),
          _prefsPut: (call) => answer(call.body),
        }),
      );
      await s.service.notificationPreferences();
      await s.service.setNotificationPreference(NotificationTopic.polls, true);
      await s.service.setNotificationPreference(
        NotificationTopic.payouts,
        false,
      );
      final item = (await s.queued()).single;
      expect(item.coalesceKey, 'prefs');
      expect(item.payload, {..._preferences, 'polls': true, 'payouts': false});
      final read = await s.service.notificationPreferences();
      expect(read[NotificationTopic.payouts], isFalse);
      expect(read[NotificationTopic.polls], isTrue);

      await s.outbox.start('u_1');
      expect(s.api.to(_prefsPut).single.body, {
        ..._preferences,
        'polls': true,
        'payouts': false,
      });
    });
  });

  group('delete account', () {
    test('closes online: nothing queues', () async {
      final s = _Service(
        FakeApi({
          'POST /me/account/close': (_) => answer({
            'status': 'closing',
            'closesAt': '2026-11-16T09:00:00.000Z',
          }),
        }),
      );
      await s.service.deleteAccount();
      expect(s.api.to('POST /me/account/close').single.body, {
        'confirm': 'DELETE',
      });
      expect(await s.queued(), isEmpty);
    });

    test('a balance or a withdrawal in flight fails it the way the screen '
        'already fails', () async {
      for (final code in ['ACCOUNT_HAS_BALANCE', 'WITHDRAWAL_IN_FLIGHT']) {
        final s = _Service(
          FakeApi({'POST /me/account/close': (_) => refusal(409, code)}),
        );
        await expectLater(s.service.deleteAccount(), throwsA(isA<Exception>()));
      }
    });

    test('while account is not live, close and restore stay on the '
        'preview', () async {
      final s = _Service(FakeApi(), accountLive: false);
      await s.service.deleteAccount();
      await s.service.restoreAccount();
      expect(s.api.calls, isEmpty);
    });
  });

  group('profileServiceProvider', () {
    Future<ProfileService> pick({ApiClient? api, Backend? mode}) async {
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (api != null) apiClientProvider.overrideWithValue(api),
          if (mode != null)
            backendProvider.overrideWith(() => FixedBackend(mode)),
        ],
      );
      addTearDown(container.dispose);
      return container.read(profileServiceProvider);
    }

    test('stays the demo by default, in the preview and without a '
        'client', () async {
      expect(await pick(), isA<DemoProfileService>());
      expect(
        await pick(api: FakeApi().client, mode: Backend.preview),
        isA<DemoProfileService>(),
      );
      expect(await pick(mode: allLive), isA<DemoProfileService>());
    });

    test('goes live with the profile, closing live with the account', () async {
      final live = await pick(api: FakeApi().client, mode: allLive);
      expect(live, isA<LiveProfileService>());
      expect((live as LiveProfileService).account, isNotNull);
      final profileOnly = await pick(
        api: FakeApi().client,
        mode: Backend.of(const {LiveFeature.profile}),
      );
      expect((profileOnly as LiveProfileService).account, isNull);
    });
  });
}
