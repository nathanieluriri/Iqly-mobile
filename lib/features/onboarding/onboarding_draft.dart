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

/// Contributors must be 18 or older (answer 10).
const minimumAge = 18;

/// Whether someone born on [born] is [minimumAge] or older on [today].
bool isAdult(DateTime? born, [DateTime? today]) {
  if (born == null) return false;
  final now = today ?? DateTime.now();
  final birthday = DateTime(born.year + minimumAge, born.month, born.day);
  return !birthday.isAfter(DateTime(now.year, now.month, now.day));
}

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

  bool get aboutYouDone =>
      profile.occupation != null && isAdult(profile.dateOfBirth);
  bool get whereYouAreDone =>
      profile.state != null &&
      profile.city.trim().isNotEmpty &&
      profile.education != null;
  bool get whatYouLikeDone => interestsComplete(profile);

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
  static const maxInterests = 3;

  /// The interest whose words the contributor types.
  static const otherInterest = 'other';

  /// 2 or 3 interests, and the words for Other when Other is one of them.
  static bool interestsComplete(OnboardingProfile profile) {
    final picked = profile.interests.length;
    if (picked < minInterests || picked > maxInterests) return false;
    return !profile.interests.contains(otherInterest) ||
        profile.otherInterest.trim().isNotEmpty;
  }

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
    'otherInterest': profile.otherInterest,
    'dateOfBirth': profile.dateOfBirth?.toIso8601String(),
    'phone': profile.phone,
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
      otherInterest: json['otherInterest'] as String? ?? '',
      dateOfBirth: DateTime.tryParse(json['dateOfBirth'] as String? ?? ''),
      phone: json['phone'] as String? ?? '',
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

  /// Anything but Student drops any university picked before.
  void setOccupation(String value) =>
      _save(state.copyWith(profile: _p.withOccupation(value)));

  /// A new state keeps the city only if that state's list has it.
  void setState(String value) {
    if (value == _p.state) return;
    final city = listedCity(value, _p.city);
    _save(_profile(state: value, city: city ?? ''));
  }

  void setCity(String value) => _save(_profile(city: value));

  /// SSCE / WAEC drops any university picked before.
  void setEducation(String value) =>
      _save(state.copyWith(profile: _p.withEducation(value)));

  void setUniversity(String value) => _save(_profile(university: value));

  void setDateOfBirth(DateTime value) => _save(_profile(dateOfBirth: value));

  void setPhone(String value) => _save(_profile(phone: value));

  /// Adds or removes [value]; a 4th pick is refused and returns false.
  bool toggleInterest(String value) {
    final next = [..._p.interests];
    if (next.contains(value)) {
      next.remove(value);
    } else if (next.length >= OnboardingDraft.maxInterests) {
      return false;
    } else {
      next.add(value);
    }
    _save(_profile(interests: next));
    return true;
  }

  void setOtherInterest(String value) => _save(_profile(otherInterest: value));

  /// Profile's Your details edits the same answers.
  void setProfile(OnboardingProfile profile) =>
      _save(state.copyWith(profile: profile));

  /// Sign out and account deletion leave nothing of the answers on the device.
  void clear() {
    state = const OnboardingDraft();
    ref.read(sharedPreferencesProvider).remove(_key);
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
    String? otherInterest,
    DateTime? dateOfBirth,
    String? phone,
  }) => this.state.copyWith(
    profile: OnboardingProfile(
      occupation: occupation ?? _p.occupation,
      state: state ?? _p.state,
      city: city ?? _p.city,
      education: education ?? _p.education,
      university: university ?? _p.university,
      interests: interests ?? _p.interests,
      otherInterest: otherInterest ?? _p.otherInterest,
      dateOfBirth: dateOfBirth ?? _p.dateOfBirth,
      phone: phone ?? _p.phone,
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

/// The first name Welcome and Done greet: the one typed at sign-up on this
/// device, else the account's.
final greetingNameProvider = Provider<String?>(
  (ref) =>
      ref.watch(sessionProvider.select((s) => s.firstName)) ??
      ref.watch(onboardingUserProvider).value?.firstName,
);
