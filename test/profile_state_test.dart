import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_draft.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden/screens/profile_harness.dart';

Future<(ProviderContainer, TestProfileService)> _container([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final shared = await SharedPreferences.getInstance();
  final service = TestProfileService();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(shared),
      repositoryProvider.overrideWithValue(DemoRepository(DemoData())),
      profileServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  await container.read(onboardingUserProvider.future);
  return (container, service);
}

void main() {
  group('profileAnswersProvider', () {
    test('falls back to the account where first run left gaps', () async {
      final (container, _) = await _container();
      final answers = container.read(profileAnswersProvider);
      expect(answers.state, 'Lagos');
      expect(answers.city, 'Ikeja');
      expect(answers.university, 'University of Lagos');
      expect(answers.interests, ['marketing_advertising', 'finance_fintech']);
    });

    test(
      'a state picked in first run keeps its own city, even empty',
      () async {
        final (container, _) = await _container({
          'onboarding.draft': jsonEncode({'state': 'Ogun', 'city': ''}),
        });
        final answers = container.read(profileAnswersProvider);
        expect(answers.state, 'Ogun');
        expect(answers.city, '');
      },
    );

    test('setProfile writes the draft onboarding reads', () async {
      final (container, _) = await _container();
      container
          .read(onboardingDraftProvider.notifier)
          .setProfile(
            const OnboardingProfile(
              state: 'Oyo',
              city: 'Ibadan',
              interests: ['education', 'other'],
            ),
          );
      final draft = container.read(onboardingDraftProvider);
      expect(draft.profile.city, 'Ibadan');
      expect(draft.lastStep, isNull);
      expect(container.read(profileAnswersProvider).interests, [
        'education',
        'other',
      ]);
      final saved = container
          .read(sharedPreferencesProvider)
          .getString('onboarding.draft');
      expect(jsonDecode(saved!)['state'], 'Oyo');
    });
  });

  group('accountDetailsProvider', () {
    test('loads from the account once, then from the device', () async {
      final (container, service) = await _container();
      final first = await container.read(accountDetailsProvider.future);
      expect(first.phone, '+234 801 234 5678');
      expect(first.dateOfBirth, DateTime(1998, 3, 14));

      container
          .read(accountDetailsProvider.notifier)
          .edit(first.copyWith(gender: 'female'));
      final raw = container
          .read(sharedPreferencesProvider)
          .getString('profile.details');
      expect(
        AccountDetails.fromJson(jsonDecode(raw!)),
        first.copyWith(gender: 'female'),
      );
      expect(service.details.gender, isNull);
    });

    test('a broken device copy falls back to the account', () async {
      final (container, _) = await _container({'profile.details': '{oops'});
      final details = await container.read(accountDetailsProvider.future);
      expect(details.stateOfOrigin, 'Lagos');
    });
  });

  group('DetailsSaveNotifier', () {
    testWidgets('typing waits for the pause, then saves once', (tester) async {
      final (container, service) = await _container();
      final saver = container.read(detailsSaveProvider.notifier);
      saver.schedule(ProfileService.typingPause);
      saver.schedule(ProfileService.typingPause);
      expect(container.read(detailsSaveProvider).status, DetailsSave.pending);
      await tester.pump(ProfileService.typingPause);
      await tester.pump();
      expect(service.saves, 1);
      expect(container.read(detailsSaveProvider).status, DetailsSave.idle);
      expect(container.read(detailsSaveProvider).saves, 1);
    });

    testWidgets('an edit during a save is saved after it', (tester) async {
      final (container, service) = await _container();
      service.hold = true;
      final saver = container.read(detailsSaveProvider.notifier);
      saver.schedule();
      await tester.pump(Duration.zero);
      expect(container.read(detailsSaveProvider).status, DetailsSave.saving);

      saver.schedule();
      final done = saver.save();
      service.hold = false;
      service.release();
      expect(await done, isTrue);
      expect(service.saves, 2);
      expect(container.read(detailsSaveProvider).status, DetailsSave.idle);
    });

    testWidgets('a refused save is failed until a retry lands', (tester) async {
      final (container, service) = await _container();
      service.fail = true;
      final saver = container.read(detailsSaveProvider.notifier);
      saver.schedule();
      await tester.pump(Duration.zero);
      expect(container.read(detailsSaveProvider).status, DetailsSave.failed);
      expect(await saver.save(), isFalse);

      service.fail = false;
      expect(await saver.save(), isTrue);
      expect(container.read(detailsSaveProvider).status, DetailsSave.idle);
    });
  });

  test('interestsLine uses the chip labels in the order picked', () {
    expect(
      interestsLine(['finance_fintech', 'product_design_innovation']),
      'Finance & fintech · Product design',
    );
  });
}
