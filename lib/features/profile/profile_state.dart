import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/backend.dart';
import '../../core/session.dart';
import '../../data/api_client.dart';
import '../../data/auth.dart';
import '../../data/live/live_account.dart';
import '../../data/local/local_providers.dart';
import '../../data/models.dart';
import '../../data/onboarding_service.dart';
import '../../data/profile_service.dart';
import '../../data/reference_data.dart';
import '../../data/repository.dart';
import '../avatar/avatar_state.dart';
import '../discover/discover_state.dart';
import '../onboarding/onboarding_draft.dart';
import '../onboarding/onboarding_flow.dart';
import '../onboarding/what_you_like_screen.dart';
import '../submit/submit_state.dart';
import '../../router.dart';
import '../../surfaces/push.dart';
import '../../surfaces/surfaces.dart';

/// The first-run answers Your details shows and edits: the onboarding draft,
/// with the account's own values where first run left a gap (skipped, or a
/// fresh install after signing in).
final profileAnswersProvider = Provider<OnboardingProfile>((ref) {
  final draft = ref.watch(onboardingDraftProvider).profile;
  final user = ref.watch(onboardingUserProvider).value;
  final ownPlace = draft.state != null;
  final merged = draft.copyWith(
    occupation: draft.occupation ?? user?.occupation,
    state: draft.state ?? _given(user?.state),
    city: ownPlace || draft.city.trim().isNotEmpty
        ? draft.city
        : user?.city ?? '',
    education: draft.education ?? user?.education,
    university:
        Reference.namesUniversity(
          draft.occupation ?? user?.occupation,
          draft.education ?? user?.education,
        )
        ? draft.university ?? _given(user?.university)
        : null,
    interests: ref.watch(feedInterestsProvider),
  );
  return OnboardingFlow.current.tidy(merged);
});

/// An account value, or null when the account has none.
String? _given(String? value) =>
    value == null || value.trim().isEmpty ? null : value;

/// Phone, date of birth, gender and state of origin, kept on the device once
/// loaded so edits survive a restart before they reach the account. While
/// the profile runs live the account's copy wins, and the device's stands
/// in only when the account cannot answer.
class AccountDetailsNotifier extends AsyncNotifier<AccountDetails> {
  static const key = 'profile.details';

  @override
  Future<AccountDetails> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    AccountDetails? device;
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        device = AccountDetails.fromJson(
          jsonDecode(raw) as Map<String, Object?>,
        );
      } on FormatException {
        await prefs.remove(key);
      }
    }
    final service = ref.watch(profileServiceProvider);
    if (ref.watch(liveLinkProvider(LiveFeature.profile)) == null) {
      return device ?? service.accountDetails();
    }
    try {
      return await service.accountDetails();
    } on Exception {
      if (device != null) return device;
      rethrow;
    }
  }

  void edit(AccountDetails next) {
    state = AsyncData(next);
    ref.read(sharedPreferencesProvider).setString(key, jsonEncode(next));
  }

  Future<void> clear() async {
    await ref.read(sharedPreferencesProvider).remove(key);
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
  final before = await ref.read(accountDetailsProvider.future);
  final answersBefore = ref.read(profileAnswersProvider);
  var current = before;
  if (details != null) {
    current = details(current);
    account.edit(current);
  }
  if (answers != null) {
    final next = answers(answersBefore);
    ref.read(onboardingDraftProvider.notifier).setProfile(next);
  }
  await ref
      .read(profileServiceProvider)
      .saveDetails(
        current,
        ref.read(profileAnswersProvider),
        before: before,
        answersBefore: answersBefore,
      );
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

/// The one way out of the account: Sign out, Keep it closed and account
/// deletion all end here. The outbox gets one short chance to send what it
/// holds, the phone stops getting the account's pushes, the API ends the
/// session, then the device forgets the account ([forgetSession]). The
/// drafts stay, as the Sign out sheet promises, unless the account is
/// [closed]: then the device lets go first, nothing of the account stays,
/// and nothing is left to send.
Future<void> forgetAccount(WidgetRef ref, {bool closed = false}) async {
  final userId = ref.read(sessionProvider).userId;
  final outbox = ref.read(outboxProvider);
  if (closed) {
    // Closing ends the account's sessions on the API, so the calls below
    // can answer 401; with the device already signed out, the session guard
    // has no one to sign out under the closing screens.
    await forgetSession(ref.read);
  } else {
    await outbox.kick().timeout(AuthTiming.lastSend, onTimeout: () {});
  }
  unawaited(outbox.stop());
  await ref.read(pushProvider)?.signingOut();
  await ref.read(authServiceProvider).signOut();
  if (!closed) await forgetSession(ref.read);
  if (closed && userId != null) {
    await ref.read(localStoreProvider).wipeUser(userId);
  }
}

/// The device's part of [forgetAccount], all there is to do once the API
/// has ended the session itself: the phone signs out and forgets what the
/// account keeps on it, all but its drafts. That is the first-run answers,
/// the cached details, the avatar, saved briefs and close reminders (their
/// scheduled reminders too), the submit autosaves and the account's cache
/// and outbox, for the account signed in or the one whose session was
/// lost.
Future<void> forgetSession(Reader read) async {
  final session = read(sessionProvider);
  final userId = session.userId ?? session.lostUserId;
  await read(sessionProvider.notifier).signOut();
  read(onboardingDraftProvider.notifier).clear();
  await forgetSubmitDrafts(read(sharedPreferencesProvider));
  await read(accountDetailsProvider.notifier).clear();
  await read(avatarProvider.notifier).forget();
  await read(savedBriefsProvider.notifier).forget();
  await read(closeRemindersProvider.notifier).forget();
  if (userId != null) {
    final store = read(localStoreProvider);
    await store.deleteCache(userId);
    await store.deleteOutbox(userId);
  }
}

/// Signs the device out when the API answers 401 to the session token. The
/// API has ended the session, not the person: the landing takes over, the
/// outbox holds, and the cache, drafts, queued writes, avatar and first-run
/// answers wait on the phone for the account's next sign-in. On the splash,
/// the hand-off finds the session signed out by itself.
final sessionGuardProvider = Provider<void>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return;
  Future<void>? running;
  Future<void> lose() async {
    await api.tokens.clear();
    final session = ref.read(sessionProvider);
    if (!session.signedIn) return;
    ref.read(pushProvider)?.sessionLost();
    if (session.userId == null) {
      // Nothing names the account, so no sign-in could claim what it left.
      await forgetSession(ref.read);
    } else {
      await ref.read(sessionProvider.notifier).lose();
    }
    final router = ref.read(routerProvider);
    final path = router.routerDelegate.currentConfiguration.uri.path;
    if (path.isNotEmpty && path != Routes.splash) router.go(Routes.landing);
  }

  final lost = api.unauthorized.listen((_) {
    running ??= lose().whenComplete(() => running = null);
  });
  ref.onDispose(lost.cancel);
});

/// What a preview launch leaves on the device that the API knows nothing
/// of: saved briefs, close reminders and the notifications scheduled for
/// them, the cached details and submit autosaves. The first launch to run
/// anything live clears them; the session, the token and the first-run
/// answers stay.
Future<void> forgetPreviewRecords(Ref ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  // Every key leaves memory before the first await, so the splash need not
  // wait for the disk before the next screen reads them.
  final removed = [
    prefs.remove(SavedBriefsNotifier.key),
    prefs.remove(CloseRemindersNotifier.key),
    prefs.remove(AccountDetailsNotifier.key),
    forgetSubmitDrafts(prefs),
  ];
  ref
    ..invalidate(savedBriefsProvider)
    ..invalidate(closeRemindersProvider)
    ..invalidate(accountDetailsProvider);
  await Future.wait(removed);
  await ref.read(surfacesProvider)?.syncCloseReminders(const []);
}
