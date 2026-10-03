import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/onboarding_service.dart';
import '../../data/reference_data.dart';
import '../../data/repository.dart';
import '../../router.dart';

/// [city] as it is spelled in [state]'s list, or null when the list does not
/// have it (a custom city). Spacing, hyphens, apostrophes and the listed
/// alternate spellings (Shaki for Saki) do not count as a difference.
String? listedCity(String? state, String city) {
  final name = placeKey(city);
  if (state == null || name.isEmpty) return null;
  return Reference.cities[state]
      ?.where((c) => placeSpellings(c).any((s) => s == name))
      .firstOrNull;
}

/// [name] reduced to lower-case letters and digits, so "Ado Ekiti" and
/// "Ado-Ekiti" compare equal.
String placeKey(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// The keys of [city] and of its alternate spellings.
Iterable<String> placeSpellings(String city) =>
    [city, ...?Reference.cityAlternates[city]].map(placeKey);

/// The screens of first run, in order. [label] is what Resume shows after
/// "Next:".
enum OnboardingStep {
  aboutYou('About you', Routes.onboardingAboutYou),
  whereYouLive('Where you live', Routes.onboardingWhereYouLive),
  whereYouStudied('Where you studied', Routes.onboardingWhereYouStudied),
  whatYouLike('What you’re into', Routes.onboardingWhatYouLike);

  const OnboardingStep(this.label, this.route);

  final String label;
  final String route;
}

class OnboardingDraft {
  const OnboardingDraft({
    this.profile = const OnboardingProfile(),
    this.lastStep,
    this.deferred = false,
  });

  final OnboardingProfile profile;

  /// The step the contributor last opened; null until they press Start.
  final OnboardingStep? lastStep;

  /// Set by "Skip for now": the app opens on Discover with the setup nudge
  /// instead of Resume.
  final bool deferred;

  bool get started => lastStep != null;

  bool get aboutYouDone => profile.occupation != null;
  bool get whereYouAreDone =>
      profile.state != null &&
      profile.city.trim().isNotEmpty &&
      profile.education != null;
  bool get whatYouLikeDone => profile.interests.length >= minInterests;

  int get stepsLeft => [
    aboutYouDone,
    whereYouAreDone,
    whatYouLikeDone,
  ].where((done) => !done).length;

  OnboardingStep? get firstIncomplete {
    if (!aboutYouDone) return OnboardingStep.aboutYou;
    if (profile.state == null || profile.city.trim().isEmpty) {
      return OnboardingStep.whereYouLive;
    }
    if (profile.education == null) return OnboardingStep.whereYouStudied;
    if (!whatYouLikeDone) return OnboardingStep.whatYouLike;
    return null;
  }

  static const minInterests = 2;

  OnboardingDraft copyWith({
    OnboardingProfile? profile,
    OnboardingStep? lastStep,
    bool? deferred,
  }) => OnboardingDraft(
    profile: profile ?? this.profile,
    lastStep: lastStep ?? this.lastStep,
    deferred: deferred ?? this.deferred,
  );

  Map<String, Object?> toJson() => {
    'occupation': profile.occupation,
    'state': profile.state,
    'city': profile.city,
    'education': profile.education,
    'university': profile.university,
    'interests': profile.interests,
    'lastStep': lastStep?.name,
    'deferred': deferred,
  };

  static OnboardingDraft fromJson(Map<String, Object?> json) => OnboardingDraft(
    profile: OnboardingProfile(
      occupation: json['occupation'] as String?,
      state: json['state'] as String?,
      city: json['city'] as String? ?? '',
      education: json['education'] as String?,
      university: json['university'] as String?,
      interests: [...(json['interests'] as List<Object?>? ?? const [])]
          .cast<String>(),
    ),
    lastStep: OnboardingStep.values
        .where((s) => s.name == json['lastStep'])
        .firstOrNull,
    deferred: json['deferred'] as bool? ?? false,
  );
}

/// Autosaves every answer to the device as it changes, so reopening the app
/// mid-flow can resume.
class OnboardingDraftNotifier extends Notifier<OnboardingDraft> {
  static const _key = 'onboarding.draft';

  @override
  OnboardingDraft build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const OnboardingDraft();
    try {
      return OnboardingDraft.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on FormatException {
      return const OnboardingDraft();
    }
  }

  OnboardingProfile get _p => state.profile;

  void setOccupation(String value) => _save(_profile(occupation: value));

  /// A new state keeps the city only if that state's list has it.
  void setState(String value) {
    if (value == _p.state) return;
    final city = listedCity(value, _p.city);
    _save(_profile(state: value, city: city ?? ''));
  }

  void setCity(String value) => _save(_profile(city: value));

  void setEducation(String value) => _save(_profile(education: value));

  void setUniversity(String value) => _save(_profile(university: value));

  void toggleInterest(String value) {
    final next = [..._p.interests];
    next.contains(value) ? next.remove(value) : next.add(value);
    _save(_profile(interests: next));
  }

  void visit(OnboardingStep step) {
    if (state.lastStep == step && !state.deferred) return;
    _save(state.copyWith(lastStep: step, deferred: false));
  }

  void defer() => _save(state.copyWith(deferred: true));

  void startOver() =>
      _save(const OnboardingDraft(lastStep: OnboardingStep.aboutYou));

  OnboardingDraft _profile({
    String? occupation,
    String? state,
    String? city,
    String? education,
    String? university,
    List<String>? interests,
  }) => this.state.copyWith(
    profile: OnboardingProfile(
      occupation: occupation ?? _p.occupation,
      state: state ?? _p.state,
      city: city ?? _p.city,
      education: education ?? _p.education,
      university: university ?? _p.university,
      interests: interests ?? _p.interests,
    ),
  );

  void _save(OnboardingDraft next) {
    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(next.toJson()));
  }
}

final onboardingDraftProvider =
    NotifierProvider<OnboardingDraftNotifier, OnboardingDraft>(
      OnboardingDraftNotifier.new,
    );

/// Where a signed-in contributor should land on launch: Resume mid-flow,
/// Welcome if first run never started, null (Discover) once done or deferred.
String? onboardingLaunchRoute(SessionState session, OnboardingDraft draft) {
  if (session.onboardingDone || draft.deferred) return null;
  return draft.started ? Routes.onboardingResume : Routes.onboarding;
}

final onboardingUserProvider = FutureProvider<User>(
  (ref) => ref.watch(repositoryProvider).user(),
);
