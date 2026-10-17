import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_onboarding_service.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/live_api.dart';

final _today = DateTime(2026, 10, 17);

/// The contract's example (3.1) as first run collects it.
final _student = OnboardingProfile(
  occupation: 'student',
  state: 'Lagos',
  city: 'Yaba',
  education: 'hnd_bsc',
  university: 'University of Lagos',
  interests: const ['finance_fintech'],
  dateOfBirth: DateTime(2001, 4, 9),
  phone: '+2348012345678',
);

void main() {
  group('the POST /me/onboarding body', () {
    test('is the contract\'s, from the first-run answers', () {
      expect(onboardingBody(_student, today: _today), {
        'skipped': false,
        'occupation': 'student',
        'sector': null,
        'sectorOther': '',
        'stateOfResidence': 'Lagos',
        'city': 'Yaba',
        'education': 'hnd_bsc',
        'university': 'University of Lagos',
        'interests': ['finance_fintech'],
        'interestOther': '',
        'dateOfBirth': '2001-04-09',
        'phone': '+2348012345678',
      });
    });

    test('carries the words for Other and the sector off the student '
        'path', () {
      const worker = OnboardingProfile(
        occupation: 'self_employed',
        sector: 'other',
        otherSector: 'Event planning',
        interests: ['education', 'other'],
        otherInterest: 'Football',
      );
      final body = onboardingBody(worker, today: _today, skipped: true);
      expect(body['skipped'], isTrue);
      expect(body['occupation'], 'self_employed');
      expect(body['sector'], 'other');
      expect(body['sectorOther'], 'Event planning');
      expect(body['interestOther'], 'Football');
      expect(body['stateOfResidence'], isNull);
      expect(body['university'], isNull);
      expect(body['dateOfBirth'], isNull);
    });

    test('leaves out what the API would refuse, so the rest lands', () {
      final body = onboardingBody(
        _student.copyWith(
          dateOfBirth: DateTime(2009, 1, 1),
          phone: ' 0803 ',
          otherSector: 'x' * 120,
        ),
        today: _today,
      );
      expect(body['dateOfBirth'], isNull);
      expect(body['phone'], isNull);
      expect((body['sectorOther']! as String).length, 80);
      expect(
        onboardingBody(_student.copyWith(phone: ''), today: _today)['phone'],
        isNull,
      );
    });
  });

  group('saveProfile', () {
    late FakeApi api;
    late MemoryLocalStore store;
    late Outbox outbox;
    late LiveOnboardingService service;

    setUp(() {
      api = FakeApi({'POST /me/onboarding': (_) => answer(profileJson())});
      store = MemoryLocalStore();
      outbox = Outbox(store);
      registerAccountWrites(outbox, api.client, store);
      service = LiveOnboardingService(
        AccountLink(
          api: api.client,
          store: store,
          outbox: outbox,
          userId: () => 'u_1',
        ),
        clock: () => _today,
      );
    });

    test(
      'queues the answers, newer ones replacing any still waiting',
      () async {
        await service.saveProfile(_student);
        await service.saveProfile(
          _student.copyWith(city: 'Ikeja'),
          skipped: true,
        );
        final item = (await store.outbox('u_1')).single;
        expect(item.kind, AccountWrite.onboarding.kind);
        expect(item.coalesceKey, 'profile:onboarding');
        expect(item.payload['city'], 'Ikeja');
        expect(item.payload['skipped'], isTrue);
        expect(api.calls, isEmpty);

        await outbox.start('u_1');
        final sent = api.to('POST /me/onboarding').single;
        expect(sent.headers['idempotency-key'], item.id);
        expect(sent.body, item.payload);
      },
    );

    test('an answer the API refuses as under 18 fails the item', () async {
      api.routes['POST /me/onboarding'] = (_) =>
          refusal(403, 'UNDER_AGE', message: 'Under 18');
      await service.saveProfile(_student);
      await outbox.start('u_1');
      final item = (await store.outbox('u_1')).single;
      expect(item.status, OutboxStatus.failed);
      expect(item.lastErrorCode, 'UNDER_AGE');
    });
  });

  test('onboardingServiceProvider goes live with the profile only', () async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer container({Backend? mode}) {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (mode != null) ...liveOverrides(FakeApi(), mode: mode),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    expect(
      container().read(onboardingServiceProvider),
      isA<DemoOnboardingService>(),
    );
    expect(
      container(mode: Backend.of(const {LiveFeature.briefs}))
          .read(onboardingServiceProvider),
      isA<DemoOnboardingService>(),
    );
    expect(
      container(mode: allLive).read(onboardingServiceProvider),
      isA<LiveOnboardingService>(),
    );
  });
}
