import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/data/reference_data.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object?> draft) async {
  SharedPreferences.setMockInitialValues({
    'onboarding.draft': jsonEncode(draft),
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('every state has a city list, capital first', () {
    expect(Reference.cities.keys, Reference.states);
    for (final cities in Reference.cities.values) {
      final rest = cities.skip(1).toList();
      final sorted = [...rest]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      expect(rest, sorted);
    }
  });

  test('a new state keeps a city its list has, in the list spelling', () async {
    final c = await _container({'state': 'Bayelsa', 'city': 'kaiama'});
    c.read(onboardingDraftProvider.notifier).setState('Kwara');
    expect(c.read(onboardingDraftProvider).profile.city, 'Kaiama');
  });

  test('a new state clears a city its list does not have', () async {
    final c = await _container({'state': 'Lagos', 'city': 'Ikeja'});
    c.read(onboardingDraftProvider.notifier).setState('Ogun');
    expect(c.read(onboardingDraftProvider).profile.city, '');
  });

  test('picking the same state leaves a custom city alone', () async {
    final c = await _container({'state': 'Lagos', 'city': 'Ilupeju'});
    c.read(onboardingDraftProvider.notifier).setState('Lagos');
    expect(c.read(onboardingDraftProvider).profile.city, 'Ilupeju');
  });

  group('interests', () {
    test('a 4th pick is refused and the 3 stay', () async {
      final c = await _container({
        'interests': ['tech_gadgets', 'education', 'health_wellness'],
      });
      final draft = c.read(onboardingDraftProvider.notifier);
      expect(draft.toggleInterest('finance_fintech'), isFalse);
      expect(c.read(onboardingDraftProvider).profile.interests, [
        'tech_gadgets',
        'education',
        'health_wellness',
      ]);
      expect(draft.toggleInterest('education'), isTrue);
      expect(draft.toggleInterest('finance_fintech'), isTrue);
      expect(c.read(onboardingDraftProvider).profile.interests, [
        'tech_gadgets',
        'health_wellness',
        'finance_fintech',
      ]);
    });

    test('2 or 3 are complete, and Other only once its words are in', () {
      OnboardingProfile pick(List<String> interests, [String words = '']) =>
          OnboardingProfile(interests: interests, otherInterest: words);
      bool done(OnboardingProfile p) => OnboardingDraft.interestsComplete(p);

      expect(done(pick(['education'])), isFalse);
      expect(done(pick(['education', 'tech_gadgets'])), isTrue);
      expect(
        done(pick(['education', 'tech_gadgets', 'health_wellness'])),
        isTrue,
      );
      expect(
        done(
          pick([
            'education',
            'tech_gadgets',
            'health_wellness',
            'energy_environment',
          ]),
        ),
        isFalse,
      );
      expect(done(pick(['education', 'other'])), isFalse);
      expect(done(pick(['education', 'other'], '  ')), isFalse);
      expect(done(pick(['education', 'other'], 'Real estate')), isTrue);
    });

    test('the Other words come back with the draft', () async {
      final c = await _container({});
      final draft = c.read(onboardingDraftProvider.notifier);
      draft.toggleInterest('other');
      draft.setOtherInterest('Real estate');
      final prefs = await SharedPreferences.getInstance();
      final reopened = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(reopened.dispose);
      expect(
        reopened.read(onboardingDraftProvider).profile.otherInterest,
        'Real estate',
      );
    });
  });

  test('SSCE / WAEC drops the university picked before', () async {
    final c = await _container({
      'occupation': 'student',
      'education': 'hnd_bsc',
      'university': 'University of Lagos',
    });
    final draft = c.read(onboardingDraftProvider.notifier);
    draft.setEducation('nd_nce');
    expect(
      c.read(onboardingDraftProvider).profile.university,
      'University of Lagos',
    );
    draft.setEducation('ssce');
    final profile = c.read(onboardingDraftProvider).profile;
    expect(profile.education, 'ssce');
    expect(profile.university, isNull);
  });

  test('anything but Student drops the university picked before', () async {
    final c = await _container({
      'occupation': 'student',
      'education': 'hnd_bsc',
      'university': 'University of Lagos',
    });
    final draft = c.read(onboardingDraftProvider.notifier);
    draft.setOccupation('student');
    expect(
      c.read(onboardingDraftProvider).profile.university,
      'University of Lagos',
    );
    draft.setOccupation('employed');
    final profile = c.read(onboardingDraftProvider).profile;
    expect(profile.occupation, 'employed');
    expect(profile.university, isNull);
  });
}
