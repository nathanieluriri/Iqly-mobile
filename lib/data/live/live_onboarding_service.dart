import '../onboarding_service.dart';
import 'live_account.dart';

/// The `POST /me/onboarding` body for [answers] (contract 3.1). What the API
/// would refuse goes as unanswered, so the other answers still land: a date
/// of birth under 18 on [today] (the About you step it leaves unanswered)
/// and a phone number of the wrong length. Typed words are cut to the
/// API's limits.
Map<String, Object?> onboardingBody(
  OnboardingProfile answers, {
  required DateTime today,
  bool skipped = false,
  bool preferNotToSay = false,
}) {
  final born = answers.dateOfBirth;
  final phone = answers.phone.trim();
  return {
    'skipped': skipped,
    'occupation': answers.occupation,
    'sector': answers.sector,
    'sectorOther': _cut(answers.otherSector, 80),
    'stateOfResidence': apiText(_cut(answers.state ?? '', 80)),
    'city': _cut(answers.city, 80),
    'education': answers.education,
    'university': apiText(_cut(answers.university ?? '', 160)),
    'interests': answers.interests,
    'interestOther': _cut(answers.otherInterest, 80),
    'dateOfBirth': born != null && isAdult(born, today) ? apiDay(born) : null,
    'phone': phone.length >= 7 && phone.length <= 40 ? phone : null,
    'gender': sentGender(answers.gender, preferNotToSay: preferNotToSay),
  };
}

String _cut(String text, int limit) {
  final trimmed = text.trim();
  return trimmed.length > limit ? trimmed.substring(0, limit) : trimmed;
}

/// [OnboardingService] on the API: the answers queue in the outbox as one
/// `POST /me/onboarding`, and newer answers replace any still waiting.
/// [gender] as the account takes it: `prefer_not_to_say` only from an API
/// whose health says `genderPreferNotToSay`; before that it goes as no
/// answer, which the API counts the same.
String? sentGender(String? gender, {required bool preferNotToSay}) =>
    gender == preferNotToSayGender && !preferNotToSay ? null : gender;

const preferNotToSayGender = 'prefer_not_to_say';

class LiveOnboardingService implements OnboardingService {
  LiveOnboardingService(
    this.link, {
    DateTime Function()? clock,
    this.preferNotToSay = false,
  }) : _clock = clock ?? DateTime.now;

  final AccountLink link;
  final bool preferNotToSay;
  final DateTime Function() _clock;

  @override
  Future<void> saveProfile(OnboardingProfile profile, {bool skipped = false}) =>
      link.queue(
        AccountWrite.onboarding,
        onboardingBody(
          profile,
          today: _clock(),
          skipped: skipped,
          preferNotToSay: preferNotToSay,
        ),
      );
}
