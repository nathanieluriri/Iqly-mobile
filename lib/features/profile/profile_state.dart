import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/session.dart';
import '../../data/auth.dart';
import '../../data/models.dart';
import '../../data/onboarding_service.dart';
import '../../data/profile_service.dart';
import '../../data/reference_data.dart';
import '../../data/repository.dart';
import '../avatar/avatar_state.dart';
import '../discover/discover_state.dart';
import '../onboarding/onboarding_draft.dart';
import '../onboarding/what_you_like_screen.dart';
import '../submit/submit_state.dart';

/// The first-run answers Your details shows and edits: the onboarding draft,
/// with the account's own values where first run left a gap (skipped, or a
/// fresh install after signing in).
final profileAnswersProvider = Provider<OnboardingProfile>((ref) {
  final draft = ref.watch(onboardingDraftProvider).profile;
  final user = ref.watch(onboardingUserProvider).value;
  final ownPlace = draft.state != null;
  return draft.copyWith(
    occupation: draft.occupation ?? user?.occupation,
    state: draft.state ?? user?.state,
    city: ownPlace || draft.city.trim().isNotEmpty
        ? draft.city
        : user?.city ?? '',
    education: draft.education ?? user?.education,
    university: draft.university ?? user?.university,
    interests: ref.watch(feedInterestsProvider),
  );
});

/// Phone, date of birth, gender and state of origin, kept on the device once
/// loaded so edits survive a restart before they reach the account.
class AccountDetailsNotifier extends AsyncNotifier<AccountDetails> {
  static const _key = 'profile.details';

  @override
  Future<AccountDetails> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        return AccountDetails.fromJson(jsonDecode(raw) as Map<String, Object?>);
      } on FormatException {
        await prefs.remove(_key);
      }
    }
    return ref.read(profileServiceProvider).accountDetails();
  }

  void edit(AccountDetails next) {
    state = AsyncData(next);
    ref.read(sharedPreferencesProvider).setString(_key, jsonEncode(next));
  }

  Future<void> clear() async {
    await ref.read(sharedPreferencesProvider).remove(_key);
    ref.invalidateSelf();
  }
}

final accountDetailsProvider =
    AsyncNotifierProvider<AccountDetailsNotifier, AccountDetails>(
      AccountDetailsNotifier.new,
    );

/// An Edit page's Save: [details] and the first-run answers [change]d,
/// on the device at once and then on the account. Throws when the account
/// refuses; the device keeps the edit either way.
Future<void> saveProfile(
  WidgetRef ref, {
  AccountDetails Function(AccountDetails details)? details,
  OnboardingProfile Function(OnboardingProfile answers)? answers,
}) async {
  final account = ref.read(accountDetailsProvider.notifier);
  var current = await ref.read(accountDetailsProvider.future);
  if (details != null) {
    current = details(current);
    account.edit(current);
  }
  if (answers != null) {
    final next = answers(ref.read(profileAnswersProvider));
    ref.read(onboardingDraftProvider.notifier).setProfile(next);
  }
  await ref
      .read(profileServiceProvider)
      .saveDetails(current, ref.read(profileAnswersProvider));
}

/// Ends the session on the API (not awaited) and forgets the account on
/// this device.
Future<void> signOut(WidgetRef ref) async {
  ref.read(profileServiceProvider).signOut().ignore();
  await forgetAccount(ref);
}

final profileBankProvider = FutureProvider<SavedBank?>(
  (ref) => ref.watch(repositoryProvider).savedBank(),
);

/// "Access Bank ••6789".
String bankLine(SavedBank bank) => '${bank.bankName} ${bank.maskedNumber}';

/// "14 March 1998".
String birthDate(DateTime date) => DateFormat('d MMMM y').format(date);

String? optionLabel(List<RefOption> options, String? value) =>
    options.where((o) => o.value == value).firstOrNull?.label;

/// The chip labels in the order picked: "Marketing & advertising · Finance
/// & fintech".
String interestsLine(List<String> values) => [
  for (final value in values)
    interestChipLabels[value] ??
        optionLabel(Reference.interests, value) ??
        value,
].join(' · ');

/// Forgets the account on this device: the session flags, the first-run
/// answers and the cached details. Sign out and account deletion end here.
Future<void> forgetAccount(WidgetRef ref) async {
  final session = ref.read(sessionProvider.notifier);
  await ref.read(authServiceProvider).signOut();
  ref.read(onboardingDraftProvider.notifier).clear();
  await forgetSubmitDrafts(ref.read(sharedPreferencesProvider));
  await ref.read(accountDetailsProvider.notifier).clear();
  await ref.read(avatarProvider.notifier).forget();
  await session.setFirstTipSeen(false);
  await session.setOnboardingDone(false);
  await session.setFirstName(null);
  await session.setSignedIn(false);
}
