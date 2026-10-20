import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend.dart';
import '../../core/session.dart';
import '../../data/auth.dart';
import '../../data/live/live_account.dart';
import '../../data/models.dart';
import '../../data/onboarding_service.dart';
import '../../data/reference_data.dart';
import '../../data/repository.dart';
import '../../router.dart';
import '../../ui/step_mark.dart';
import 'onboarding_flow.dart';

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

/// The screens of first run; OnboardingFlow says their order. [label] is
/// what Resume shows after "Next:", [mark] the step mark's part.
enum OnboardingStep {
  gender('Your gender', Routes.onboardingGender, IqStepMarkStep.oneOfThree),
  aboutYou('About you', Routes.onboardingAboutYou, IqStepMarkStep.oneOfThree),
  whereYouStudied(
    'Where you study',
    Routes.onboardingWhereYouStudied,
    IqStepMarkStep.twoOfThree,
  ),
  yourWork('Your work', Routes.onboardingYourWork, IqStepMarkStep.twoOfThree),
  whereYouLive(
    'Where you live',
    Routes.onboardingWhereYouLive,
    IqStepMarkStep.twoOfThree,
  ),
  whatYouLike(
    'What you’re into',
    Routes.onboardingWhatYouLike,
    IqStepMarkStep.threeOfThree,
  );

  const OnboardingStep(this.label, this.route, this.mark);

  final String label;
  final String route;
  final IqStepMarkStep mark;
}

class OnboardingDraft {
  const OnboardingDraft({
    this.profile = const OnboardingProfile(),
    this.lastStep,
    this.deferred = false,
    this.underAge = false,
  });

  final OnboardingProfile profile;

  /// The step the contributor last opened; null until they press Start.
  final OnboardingStep? lastStep;

  /// Set by "Skip for now": the app opens on Discover with the setup nudge
  /// instead of Resume.
  final bool deferred;

  /// The account refused the date of birth as under 18; About you says so
  /// until another date is picked.
  final bool underAge;

  bool get started => lastStep != null;

  /// The step mark's parts with something left to answer.
  int get stepsLeft => OnboardingFlow.current.partsLeft(profile);

  OnboardingStep? get firstIncomplete =>
      OnboardingFlow.current.firstUnanswered(profile);

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
    bool? underAge,
  }) => OnboardingDraft(
    profile: profile ?? this.profile,
    lastStep: lastStep ?? this.lastStep,
    deferred: deferred ?? this.deferred,
    underAge: underAge ?? this.underAge,
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
    'sector': profile.sector,
    'otherSector': profile.otherSector,
    'gender': profile.gender,
    'lastStep': lastStep?.name,
    'deferred': deferred,
    'underAge': underAge,
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
      sector: json['sector'] as String?,
      otherSector: json['otherSector'] as String? ?? '',
      gender: json['gender'] as String?,
    ),
    lastStep: OnboardingStep.values
        .where((s) => s.name == json['lastStep'])
        .firstOrNull,
    deferred: json['deferred'] as bool? ?? false,
    underAge: json['underAge'] as bool? ?? false,
  );
}

/// Autosaves every answer to the device as it changes, so reopening the app
/// mid-flow can resume.
class OnboardingDraftNotifier extends Notifier<OnboardingDraft> {
  static const _key = 'onboarding.draft';

  @override
  OnboardingDraft build() {
    ref.watch(accountProvider);
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const OnboardingDraft();
    try {
      return OnboardingDraft.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on FormatException {
      return const OnboardingDraft();
    }
  }

  OnboardingProfile get _p => state.profile;

  /// Drops the answers the new path never asks: a student's sector, or
  /// anyone else's education and university.
  void setOccupation(String value) => _save(
    state.copyWith(
      profile: OnboardingFlow.current.tidy(_p.withOccupation(value)),
    ),
  );

  void setGender(String value) => _save(_profile(gender: value));

  void setSector(String value) => _save(_profile(sector: value));

  void setOtherSector(String value) => _save(_profile(otherSector: value));

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

  void setDateOfBirth(DateTime value) =>
      _save(_profile(dateOfBirth: value).copyWith(underAge: false));

  /// The account refused the date of birth as under 18: it goes, and first
  /// run picks up again at About you, which says why.
  void refuseDateOfBirth() => _save(
    state.copyWith(
      profile: _p.withoutDateOfBirth(),
      lastStep: OnboardingStep.aboutYou,
      underAge: true,
    ),
  );

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
      _save(const OnboardingDraft(lastStep: OnboardingStep.gender));

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
    String? sector,
    String? otherSector,
    String? gender,
  }) => this.state.copyWith(
    profile: _p.copyWith(
      occupation: occupation,
      state: state,
      city: city,
      education: education,
      university: university,
      interests: interests,
      otherInterest: otherInterest,
      dateOfBirth: dateOfBirth,
      phone: phone,
      sector: sector,
      otherSector: otherSector,
      gender: gender,
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

/// The account's name, email and profile answers: from `GET /me` while the
/// profile runs live (the session's name alone when the API cannot say),
/// else the repository's.
final onboardingUserProvider = FutureProvider<User>((ref) {
  if (ref.watch(liveLinkProvider(LiveFeature.profile)) == null) {
    return ref.watch(repositoryProvider).user();
  }
  return _liveUser(ref);
});

Future<User> _liveUser(Ref ref) async {
  try {
    final me = await ref.watch(meProvider.future);
    if (me != null) return me.toUser();
  } on Exception {
    // Offline with nothing kept: the name the session holds.
  }
  final name = ref.read(sessionProvider).name ?? '';
  return Me(id: '', name: name, email: '').toUser();
}

/// The signed-in account's name: kept on this device since sign-in, else
/// asked of the API once (an account signed in before names were kept).
final accountNameProvider = Provider<String?>((ref) {
  final kept = ref.watch(sessionProvider.select((s) => s.name));
  if (kept != null) return kept;
  if (!ref.watch(sessionProvider.select((s) => s.signedIn))) return null;
  return ref.watch(_askedNameProvider).value;
});

final _askedNameProvider = FutureProvider<String?>((ref) async {
  final scope = ref.watch(accountScopeProvider);
  final name = await scope.guard(ref.read(authServiceProvider).accountName());
  if (name != null) await ref.read(sessionProvider.notifier).setName(name);
  return name;
});

/// The first name Welcome, Resume and Done greet (owner, 16 Oct: never the
/// sample account's): the account's own, or no name at all.
final greetingNameProvider = Provider<String?>(
  (ref) =>
      ref.watch(sessionProvider.select((s) => s.firstName)) ??
      ref.watch(accountNameProvider)?.split(' ').first,
);
