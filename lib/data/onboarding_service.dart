import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reference_data.dart';

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
      );
}

/// Sends the first-run answers to the contributor's profile.
abstract class OnboardingService {
  Future<void> saveProfile(OnboardingProfile profile);
}

class DemoOnboardingService implements OnboardingService {
  const DemoOnboardingService({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;

  @override
  Future<void> saveProfile(OnboardingProfile profile) =>
      Future<void>.delayed(delay);
}

final onboardingServiceProvider = Provider<OnboardingService>(
  (ref) => const DemoOnboardingService(),
);
