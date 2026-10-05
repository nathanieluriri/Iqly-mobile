import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.dateOfBirth,
    this.phone = '',
  });

  final String? occupation;
  final String? state;
  final String city;
  final String? education;
  final String? university;
  final List<String> interests;

  /// Collected on About you; under 18 is blocked there (answers 10 and 17).
  final DateTime? dateOfBirth;

  /// Optional until the first withdrawal (answer 17).
  final String phone;
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
