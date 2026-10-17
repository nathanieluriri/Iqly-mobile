import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import '../core/deadline.dart';
import 'live/live_account.dart';
import 'live/live_onboarding_service.dart';
import 'live/live_repository.dart';
import 'reference_data.dart';

/// Contributors must be 18 or older (answer 10).
const minimumAge = 18;

/// Whether someone born on [born] is [minimumAge] or older on [today].
bool isAdult(DateTime? born, [DateTime? today]) {
  if (born == null) return false;
  final now = today ?? DateTime.now();
  final birthday = DateTime(born.year + minimumAge, born.month, born.day);
  return !birthday.isAfter(DateTime(now.year, now.month, now.day));
}

/// What first run collects. Option fields hold the API values from
/// [Reference]; state and university are stored by name, as the web profile
/// does.
class OnboardingProfile {
  const OnboardingProfile({
    this.occupation,
    this.state,
    this.city = '',
    this.education,
    this.university,
    this.interests = const [],
    this.otherInterest = '',
    this.dateOfBirth,
    this.phone = '',
    this.sector,
    this.otherSector = '',
  });

  final String? occupation;
  final String? state;
  final String city;
  final String? education;
  final String? university;
  final List<String> interests;

  /// What "Other" means, typed when the Other interest is picked. The API has
  /// no field for it yet, so it stays with the answers on the device.
  final String otherInterest;

  /// Collected on About you; under 18 is blocked there (answers 10 and 17).
  final DateTime? dateOfBirth;

  /// Optional until the first withdrawal (answer 17).
  final String phone;

  /// What anyone but a student works in, from [Reference.sectors].
  final String? sector;

  /// What "Other" means, typed when the Other sector is picked.
  final String otherSector;

  /// Nothing answered yet.
  bool get isEmpty =>
      occupation == null &&
      state == null &&
      city.trim().isEmpty &&
      education == null &&
      university == null &&
      interests.isEmpty &&
      otherInterest.trim().isEmpty &&
      dateOfBirth == null &&
      phone.trim().isEmpty &&
      sector == null &&
      otherSector.trim().isEmpty;

  /// The same answers with no date of birth.
  OnboardingProfile withoutDateOfBirth() => OnboardingProfile(
    occupation: occupation,
    state: state,
    city: city,
    education: education,
    university: university,
    interests: interests,
    otherInterest: otherInterest,
    phone: phone,
    sector: sector,
    otherSector: otherSector,
  );

  /// Keeps every field the change does not name, so an edit to one answer
  /// never drops another.
  OnboardingProfile copyWith({
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
  }) => OnboardingProfile(
    occupation: occupation ?? this.occupation,
    state: state ?? this.state,
    city: city ?? this.city,
    education: education ?? this.education,
    university: university ?? this.university,
    interests: interests ?? this.interests,
    otherInterest: otherInterest ?? this.otherInterest,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    phone: phone ?? this.phone,
    sector: sector ?? this.sector,
    otherSector: otherSector ?? this.otherSector,
  );

  /// The same answers without what is never asked on this path: no
  /// education or university without [keepStudy], no sector without
  /// [keepWork].
  OnboardingProfile keeping({
    required bool keepStudy,
    required bool keepWork,
  }) => OnboardingProfile(
    occupation: occupation,
    state: state,
    city: city,
    education: keepStudy ? education : null,
    university: keepStudy ? university : null,
    interests: interests,
    otherInterest: otherInterest,
    dateOfBirth: dateOfBirth,
    phone: phone,
    sector: keepWork ? sector : null,
    otherSector: keepWork ? otherSector : '',
  );

  /// The same answers with [education] set, dropping the university when
  /// the answers no longer name one.
  OnboardingProfile withEducation(String education) =>
      _named(occupation, education);

  /// The same answers with [occupation] set, dropping the university when
  /// the answers no longer name one.
  OnboardingProfile withOccupation(String occupation) =>
      _named(occupation, education);

  OnboardingProfile _named(String? occupation, String? education) =>
      OnboardingProfile(
        occupation: occupation,
        state: state,
        city: city,
        education: education,
        university: Reference.namesUniversity(occupation, education)
            ? university
            : null,
        interests: interests,
        otherInterest: otherInterest,
        dateOfBirth: dateOfBirth,
        phone: phone,
        sector: sector,
        otherSector: otherSector,
      );
}

/// Sends the first-run answers to the contributor's profile.
abstract class OnboardingService {
  /// How long finishing first run waits for Start here's briefs before it
  /// goes on without them.
  static const briefsWait = Duration(seconds: 2);

  /// [skipped] when first run ended on Skip for now.
  Future<void> saveProfile(OnboardingProfile profile, {bool skipped = false});
}

class DemoOnboardingService implements OnboardingService {
  const DemoOnboardingService({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;

  @override
  Future<void> saveProfile(OnboardingProfile profile, {bool skipped = false}) =>
      Future<void>.delayed(delay);
}

/// First run in a live launch that pauses the profile: the answers stay on
/// the phone, in the draft, and nothing pretends they reached the account.
class PausedOnboardingService implements OnboardingService {
  const PausedOnboardingService();

  @override
  Future<void> saveProfile(OnboardingProfile profile, {bool skipped = false}) =>
      Future.error(const FeaturePaused(LiveFeature.profile));
}

/// The demo in a preview launch; in a live one the API's outbox, or a
/// refusal while the profile is paused.
final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  if (ref.watch(liveModeProvider).isPreview) {
    return const DemoOnboardingService();
  }
  final link = ref.watch(liveLinkProvider(LiveFeature.profile));
  if (link == null) return const PausedOnboardingService();
  return LiveOnboardingService(link, clock: ref.watch(clockProvider));
});
