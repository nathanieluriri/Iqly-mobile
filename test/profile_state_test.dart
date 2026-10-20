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

    test('SSCE / WAEC answers carry no university, even the account '
        'one', () async {
      final (container, _) = await _container({
        'onboarding.draft': jsonEncode({'education': 'ssce'}),
      });
      final answers = container.read(profileAnswersProvider);
      expect(answers.education, 'ssce');
      expect(answers.university, isNull);
    });

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
          .edit(first.copyWith(gender: 'male'));
      final raw = container
          .read(sharedPreferencesProvider)
          .getString('profile.details');
      expect(
        AccountDetails.fromJson(jsonDecode(raw!)),
        first.copyWith(gender: 'male'),
      );
      expect(service.details.gender, 'female');
    });

    test('a broken device copy falls back to the account', () async {
      final (container, _) = await _container({'profile.details': '{oops'});
      final details = await container.read(accountDetailsProvider.future);
      expect(details.stateOfOrigin, 'Lagos');
    });
  });

  test('the account fills the occupation and education first run left '
      'empty', () async {
    final (container, _) = await _container();
    expect(container.read(profileAnswersProvider).occupation, 'student');
    expect(container.read(profileAnswersProvider).education, 'hnd_bsc');
  });

  test('interestsLine uses the chip labels in the order picked', () {
    expect(
      interestsLine(['finance_fintech', 'product_design_innovation']),
      'Finance & fintech · Product design',
    );
  });
}
