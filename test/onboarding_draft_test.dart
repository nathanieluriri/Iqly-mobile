import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/session.dart';
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
}
