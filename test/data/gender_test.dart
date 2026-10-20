import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/live/live_onboarding_service.dart';
import 'package:iqly_mobile/data/live/live_profile_service.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/data/profile_service.dart';

void main() {
  final today = DateTime(2026, 10, 20);

  group('Prefer not to say goes only to an API that takes it', () {
    test('first run sends it with genderPreferNotToSay', () {
      const answers = OnboardingProfile(gender: 'prefer_not_to_say');
      expect(
        onboardingBody(answers, today: today, preferNotToSay: true)['gender'],
        'prefer_not_to_say',
      );
      expect(onboardingBody(answers, today: today)['gender'], isNull);
    });

    test('male and female always go', () {
      for (final gender in ['male', 'female']) {
        expect(
          onboardingBody(
            OnboardingProfile(gender: gender),
            today: today,
          )['gender'],
          gender,
        );
      }
    });

    test('the profile sends no answer in its place before then', () {
      const details = AccountDetails(gender: 'prefer_not_to_say');
      const answers = OnboardingProfile();
      expect(profileFields(details, answers)['gender'], isNull);
      expect(
        profileFields(details, answers, preferNotToSay: true)['gender'],
        'prefer_not_to_say',
      );
    });
  });
}
