import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import '../core/session.dart';
import 'live/live_account.dart';
import 'live/live_profile_service.dart';
import 'live/live_repository.dart';
import 'onboarding_service.dart';

/// The profile fields first run does not ask: the phone number from sign-up,
/// date of birth, gender and state of origin. [gender] holds a
/// Reference.genders value.
class AccountDetails {
  const AccountDetails({
    this.phone = '',
    this.dateOfBirth,
    this.gender,
    this.stateOfOrigin,
    this.phoneVerified = false,
  });

  final String phone;

  /// The number was confirmed by an SMS code (contract 13.2); a different
  /// number is not.
  final bool phoneVerified;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? stateOfOrigin;

  AccountDetails copyWith({
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
    String? stateOfOrigin,
    bool? phoneVerified,
  }) => AccountDetails(
    phone: phone ?? this.phone,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    gender: gender ?? this.gender,
    stateOfOrigin: stateOfOrigin ?? this.stateOfOrigin,
    phoneVerified:
        phoneVerified ??
        (phone == null || phone == this.phone ? this.phoneVerified : false),
  );

  Map<String, Object?> toJson() => {
    'phone': phone,
    'dateOfBirth': dateOfBirth?.toIso8601String(),
    'gender': gender,
    'stateOfOrigin': stateOfOrigin,
    if (phoneVerified) 'phoneVerified': true,
  };

  static AccountDetails fromJson(Map<String, Object?> json) {
    final born = json['dateOfBirth'] as String?;
    return AccountDetails(
      phone: json['phone'] as String? ?? '',
      dateOfBirth: born == null ? null : DateTime.tryParse(born),
      gender: json['gender'] as String?,
      stateOfOrigin: json['stateOfOrigin'] as String?,
      phoneVerified: json['phoneVerified'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AccountDetails &&
      other.phone == phone &&
      other.dateOfBirth == dateOfBirth &&
      other.gender == gender &&
      other.stateOfOrigin == stateOfOrigin &&
      other.phoneVerified == phoneVerified;

  @override
  int get hashCode =>
      Object.hash(phone, dateOfBirth, gender, stateOfOrigin, phoneVerified);
}

/// The switches on Notification preferences (Flags.notificationPreferences).
enum NotificationTopic {
  closingSoon,
  results,
  payouts,
  newBriefs,
  polls;

  /// Every switch but Polls starts on (contract 3.3).
  bool get onByDefault => this != polls;
}

/// The account side of Profile: Your details, notification preferences and
/// delete account. The demo answers after a short delay; the live API
/// replaces it behind the same interface.
abstract class ProfileService {
  Future<AccountDetails> accountDetails();

  /// Your details: the account fields and the first-run answers together,
  /// as the profile endpoint takes them. [before] and [answersBefore] are
  /// what the edit started from, so only what changed goes to the account.
  Future<void> saveDetails(
    AccountDetails details,
    OnboardingProfile answers, {
    AccountDetails? before,
    OnboardingProfile? answersBefore,
  });

  Future<Map<NotificationTopic, bool>> notificationPreferences();
  Future<void> setNotificationPreference(NotificationTopic topic, bool on);

  /// Closes the account. Signing in within [undoWindow] reopens it.
  Future<void> deleteAccount();

  static const undoWindow = Duration(days: 30);

  /// Reopens an account that is closing, within [undoWindow].
  Future<void> restoreAccount();

  /// Typing autosaves once it pauses this long, so a phone number is one
  /// call, not one per digit.
  static const typingPause = Duration(milliseconds: 800);

  /// A new code can be asked for this long after the last one was sent.
  static const codeResendAfter = Duration(seconds: 45);

  /// The resend countdown's step.
  static const countdownStep = Duration(seconds: 1);
}

/// Answers with the Figma values (B7 · Your details 40:141: the phone,
/// date of birth and state of origin are illustrative) and remembers what
/// is saved for as long as the app runs.
class DemoProfileService implements ProfileService {
  DemoProfileService({this.delay = const Duration(milliseconds: 600)});

  final Duration delay;

  AccountDetails details = AccountDetails(
    phone: '+234 801 234 5678',
    dateOfBirth: DateTime(1998, 3, 14),
    gender: 'female',
    stateOfOrigin: 'Lagos',
  );
  OnboardingProfile? answers;
  final preferences = {
    for (final topic in NotificationTopic.values) topic: topic.onByDefault,
  };
  int deletions = 0;
  int restores = 0;

  Future<void> _wait() =>
      delay == Duration.zero ? Future.value() : Future<void>.delayed(delay);

  @override
  Future<AccountDetails> accountDetails() async => details;

  @override
  Future<void> saveDetails(
    AccountDetails details,
    OnboardingProfile answers, {
    AccountDetails? before,
    OnboardingProfile? answersBefore,
  }) async {
    await _wait();
    this.details = details;
    this.answers = answers;
  }

  @override
  Future<Map<NotificationTopic, bool>> notificationPreferences() async => {
    ...preferences,
  };

  @override
  Future<void> setNotificationPreference(
    NotificationTopic topic,
    bool on,
  ) async {
    preferences[topic] = on;
  }

  @override
  Future<void> deleteAccount() async {
    await _wait();
    deletions++;
  }

  @override
  Future<void> restoreAccount() async {
    await _wait();
    restores++;
  }
}

/// The profile a live launch pauses: every read fails and every write
/// refuses, before anything is sent and without the demo's sample details.
class PausedProfileService implements ProfileService {
  const PausedProfileService();

  static Future<Never> _paused() =>
      Future.error(const FeaturePaused(LiveFeature.profile));

  @override
  Future<AccountDetails> accountDetails() => _paused();

  @override
  Future<void> saveDetails(
    AccountDetails details,
    OnboardingProfile answers, {
    AccountDetails? before,
    OnboardingProfile? answersBefore,
  }) => _paused();

  @override
  Future<Map<NotificationTopic, bool>> notificationPreferences() => _paused();

  @override
  Future<void> setNotificationPreference(NotificationTopic topic, bool on) =>
      _paused();

  @override
  Future<void> deleteAccount() => _paused();

  @override
  Future<void> restoreAccount() => _paused();
}

/// The demo in a preview launch. In a live one the API, with close and
/// restore on it while the account runs live too; a paused profile refuses.
final profileServiceProvider = Provider<ProfileService>((ref) {
  ref.watch(accountProvider);
  if (ref.watch(liveModeProvider).isPreview) return DemoProfileService();
  final link = ref.watch(liveLinkProvider(LiveFeature.profile));
  if (link == null) return const PausedProfileService();
  final account = ref.watch(liveLinkProvider(LiveFeature.account));
  return LiveProfileService(
    link,
    account: account == null ? null : LiveAccount(account),
    preferNotToSay: ref
        .watch(liveModeProvider)
        .isLive(LiveFeature.genderPreferNotToSay),
  );
});
