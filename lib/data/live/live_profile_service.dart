import 'package:flutter/foundation.dart' show listEquals;

import '../api_client.dart';
import '../onboarding_service.dart';
import '../profile_service.dart';
import '../reference_data.dart';
import 'live_account.dart';

/// The contributor profile as the API answers it (contract 3.2), the
/// fields the app reads. A value the app does not know reads as
/// unanswered.
class ContributorProfile {
  const ContributorProfile({
    this.phone,
    this.dateOfBirth,
    this.gender,
    this.stateOfOrigin,
    this.stateOfResidence,
    this.city,
    this.occupations = const [],
    this.education,
    this.university,
    this.sector,
    this.sectorOther,
    this.interests = const [],
    this.interestOther,
    this.onboardingCompletedAt,
  });

  factory ContributorProfile.fromJson(Map<String, dynamic> json) =>
      ContributorProfile(
        phone: apiText(json['phone']),
        dateOfBirth: apiDate(json['dateOfBirth']),
        gender: knownValue(json['gender'], Reference.genders),
        stateOfOrigin: apiText(json['stateOfOrigin']),
        stateOfResidence: apiText(json['stateOfResidence']),
        city: apiText(json['city']),
        occupations: knownValues(json['occupations'], Reference.occupations),
        education: knownValue(json['education'], Reference.education),
        university: apiText(json['university']),
        sector: knownValue(json['sector'], Reference.sectors),
        sectorOther: apiText(json['sectorOther']),
        interests: knownValues(json['interests'], Reference.interests),
        interestOther: apiText(json['interestOther']),
        onboardingCompletedAt: apiTime(json['onboardingCompletedAt']),
      );

  final String? phone;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? stateOfOrigin;
  final String? stateOfResidence;
  final String? city;
  final List<String> occupations;
  final String? education;
  final String? university;
  final String? sector;
  final String? sectorOther;
  final List<String> interests;
  final String? interestOther;
  final DateTime? onboardingCompletedAt;

  AccountDetails get details => AccountDetails(
    phone: phone ?? '',
    dateOfBirth: dateOfBirth,
    gender: gender,
    stateOfOrigin: stateOfOrigin,
  );
}

/// The `PATCH /profiles/contributors/me` fields for the account details and
/// the first-run answers (contract 3.2). Blank text is null.
Map<String, Object?> profileFields(
  AccountDetails details,
  OnboardingProfile answers,
) => {
  'phone': apiText(details.phone),
  'dateOfBirth': switch (details.dateOfBirth) {
    final born? => apiDay(born),
    null => null,
  },
  'gender': details.gender,
  'stateOfOrigin': apiText(details.stateOfOrigin),
  'stateOfResidence': apiText(answers.state),
  'city': apiText(answers.city),
  'occupations': [?answers.occupation],
  'education': answers.education,
  'university': apiText(answers.university),
  'sector': answers.sector,
  'sectorOther': apiText(answers.otherSector),
  'interests': answers.interests,
  'interestOther': apiText(answers.otherInterest),
};

/// The fields of [after] that differ from [before].
Map<String, Object?> changedFields(
  Map<String, Object?> before,
  Map<String, Object?> after,
) => {
  for (final MapEntry(:key, :value) in after.entries)
    if (!_same(before[key], value)) key: value,
};

bool _same(Object? a, Object? b) =>
    a is List && b is List ? listEquals(a, b) : a == b;

/// The switches as the API keeps them (contract 3.3); one it leaves out is
/// at its default.
Map<NotificationTopic, bool> preferencesFrom(Map<String, dynamic> json) => {
  for (final topic in NotificationTopic.values)
    topic: switch (json[topic.name]) {
      final bool on => on,
      _ => topic.onByDefault,
    },
};

Map<String, Object?> preferencesJson(Map<NotificationTopic, bool> switches) => {
  for (final topic in NotificationTopic.values)
    topic.name: switches[topic] ?? topic.onByDefault,
};

/// [ProfileService] on the API. Reads go to the network first and fall back
/// to the copy kept on the phone; edits and switches queue in the outbox
/// and show at once, the server copy with the edits still to go laid over
/// it. Close and restore are online only.
class LiveProfileService implements ProfileService {
  LiveProfileService(this.link, {this.account, ProfileService? preview})
    : _preview = preview ?? DemoProfileService();

  final AccountLink link;

  /// Null while `account` is not live this launch; close and restore then
  /// stay on the preview.
  final LiveAccount? account;
  final ProfileService _preview;
  Map<NotificationTopic, bool>? _preferences;

  /// A new account has no profile yet, so no details.
  @override
  Future<AccountDetails> accountDetails() async {
    Map<String, dynamic> stored;
    try {
      stored = await link.fetch(
        '/profiles/contributors/me',
        AccountKeys.profile,
      );
    } on ApiRefused catch (refused) {
      if (refused.status != 404) rethrow;
      stored = const {};
    }
    final edits = await link.waiting(AccountWrite.profile);
    return ContributorProfile.fromJson({
      ...stored,
      for (final edit in edits) ...edit,
    }).details;
  }

  /// Without [before] and [answersBefore] every field goes.
  @override
  Future<void> saveDetails(
    AccountDetails details,
    OnboardingProfile answers, {
    AccountDetails? before,
    OnboardingProfile? answersBefore,
  }) async {
    final after = profileFields(details, answers);
    final changed = before == null && answersBefore == null
        ? after
        : changedFields(
            profileFields(before ?? details, answersBefore ?? answers),
            after,
          );
    if (changed.isEmpty) return;
    await link.queue(
      AccountWrite.profile,
      changed,
      merge: (older, newer) => {...older, ...newer},
    );
  }

  @override
  Future<Map<NotificationTopic, bool>> notificationPreferences() async {
    final stored = await link.fetch(
      '/me/notification-preferences',
      AccountKeys.preferences,
    );
    final waiting = await link.waiting(AccountWrite.preferences);
    return _preferences = preferencesFrom(waiting.lastOrNull ?? stored);
  }

  @override
  Future<void> setNotificationPreference(
    NotificationTopic topic,
    bool on,
  ) async {
    final current = _preferences ?? await notificationPreferences();
    final next = {...current, topic: on};
    await link.queue(AccountWrite.preferences, preferencesJson(next));
    _preferences = next;
  }

  @override
  Future<void> deleteAccount() => account?.close() ?? _preview.deleteAccount();

  @override
  Future<void> restoreAccount() =>
      account?.restore() ?? _preview.restoreAccount();
}
