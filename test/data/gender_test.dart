import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/live/live_onboarding_service.dart';
import 'package:iqly_mobile/data/live/live_profile_service.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_draft.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_flow.dart';

void main() {
  final today = DateTime(2026, 10, 20);

  group('gender (contract 14.2)', () {
    test('first run sends it, Prefer not to say included, with '
        'genderRequired', () {
      for (final gender in ['male', 'female', 'prefer_not_to_say']) {
        expect(
          onboardingBody(
            OnboardingProfile(gender: gender),
            today: today,
            askGender: true,
          )['gender'],
          gender,
        );
      }
    });

    test('without genderRequired first run sends none, as before', () {
      expect(
        onboardingBody(
          const OnboardingProfile(gender: 'female'),
          today: today,
        ).containsKey('gender'),
        isFalse,
      );
    });

    test('the profile takes it as it is', () {
      expect(
        profileFields(
          const AccountDetails(gender: 'prefer_not_to_say'),
          const OnboardingProfile(),
        )['gender'],
        'prefer_not_to_say',
      );
    });

    test('without genderRequired first run does not ask', () {
      addTearDown(() => OnboardingFlow.askGender = true);
      OnboardingFlow.askGender = false;
      expect(
        OnboardingFlow.byOccupation.path(const OnboardingProfile()).first,
        OnboardingStep.aboutYou,
      );
    });
  });
}
