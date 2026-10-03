import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final String phone;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? stateOfOrigin;

  AccountDetails copyWith({
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
    String? stateOfOrigin,
  }) => AccountDetails(
    phone: phone ?? this.phone,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    gender: gender ?? this.gender,
    stateOfOrigin: stateOfOrigin ?? this.stateOfOrigin,
  );

  Map<String, Object?> toJson() => {
    'phone': phone,
    'dateOfBirth': dateOfBirth?.toIso8601String(),
    'gender': gender,
    'stateOfOrigin': stateOfOrigin,
  };

  static AccountDetails fromJson(Map<String, Object?> json) {
    final born = json['dateOfBirth'] as String?;
    return AccountDetails(
      phone: json['phone'] as String? ?? '',
      dateOfBirth: born == null ? null : DateTime.tryParse(born),
      gender: json['gender'] as String?,
      stateOfOrigin: json['stateOfOrigin'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AccountDetails &&
      other.phone == phone &&
      other.dateOfBirth == dateOfBirth &&
      other.gender == gender &&
      other.stateOfOrigin == stateOfOrigin;

  @override
  int get hashCode => Object.hash(phone, dateOfBirth, gender, stateOfOrigin);
}

/// The switches on Notification preferences (Flags.notificationPreferences).
enum NotificationTopic { closingSoon, results, payouts, newBriefs, polls }

/// The account side of Profile: Your details, notification preferences,
/// sign out and delete account. The demo answers after a short delay; the
/// live API replaces it behind the same interface.
abstract class ProfileService {
  Future<AccountDetails> accountDetails();

  /// Your details: the account fields and the first-run answers together,
  /// as the profile endpoint takes them.
  Future<void> saveDetails(AccountDetails details, OnboardingProfile answers);

  Future<Map<NotificationTopic, bool>> notificationPreferences();
  Future<void> setNotificationPreference(NotificationTopic topic, bool on);

  Future<void> signOut();

  /// Closes the account. Signing in within [undoWindow] reopens it.
  Future<void> deleteAccount();

  static const undoWindow = Duration(days: 30);

  /// Typing autosaves once it pauses this long, so a phone number is one
  /// call, not one per digit.
  static const typingPause = Duration(milliseconds: 800);
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
    stateOfOrigin: 'Lagos',
  );
  OnboardingProfile? answers;
  final preferences = {
    for (final topic in NotificationTopic.values)
      topic: topic != NotificationTopic.polls,
  };
  int signOuts = 0;
  int deletions = 0;

  Future<void> _wait() =>
      delay == Duration.zero ? Future.value() : Future<void>.delayed(delay);

  @override
  Future<AccountDetails> accountDetails() async => details;

  @override
  Future<void> saveDetails(
    AccountDetails details,
    OnboardingProfile answers,
  ) async {
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
  Future<void> signOut() async {
    await _wait();
    signOuts++;
  }

  @override
  Future<void> deleteAccount() async {
    await _wait();
    deletions++;
  }
}

final profileServiceProvider = Provider<ProfileService>(
  (ref) => DemoProfileService(),
);
