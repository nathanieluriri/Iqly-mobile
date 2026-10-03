import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/onboarding_service.dart';
import '../../data/profile_service.dart';
import '../../data/reference_data.dart';
import '../../data/repository.dart';
import '../discover/discover_state.dart';
import '../onboarding/onboarding_draft.dart';
import '../onboarding/what_you_like_screen.dart';

/// The first-run answers Your details shows and edits: the onboarding draft,
/// with the account's own values where first run left a gap (skipped, or a
/// fresh install after signing in).
final profileAnswersProvider = Provider<OnboardingProfile>((ref) {
  final draft = ref.watch(onboardingDraftProvider).profile;
  final user = ref.watch(onboardingUserProvider).value;
  final ownPlace = draft.state != null;
  return OnboardingProfile(
    occupation: draft.occupation,
    state: draft.state ?? user?.state,
    city: ownPlace || draft.city.trim().isNotEmpty
        ? draft.city
        : user?.city ?? '',
    education: draft.education,
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

enum DetailsSave { idle, pending, saving, failed }

class DetailsSaveState {
  const DetailsSaveState({this.status = DetailsSave.idle, this.saves = 0});

  final DetailsSave status;

  /// Completed saves; each one pops the autosave check.
  final int saves;

  bool get settled => status == DetailsSave.idle;

  DetailsSaveState to(DetailsSave status, {bool saved = false}) =>
      DetailsSaveState(status: status, saves: saves + (saved ? 1 : 0));
}

/// Your details autosaves: every edit reaches the device at once and the
/// account shortly after (typing waits for a pause). It outlives the
/// screen, so leaving mid-save still saves.
class DetailsSaveNotifier extends Notifier<DetailsSaveState> {
  Timer? _timer;
  Future<bool>? _running;

  @override
  DetailsSaveState build() {
    ref.onDispose(() => _timer?.cancel());
    return const DetailsSaveState();
  }

  void schedule([Duration delay = Duration.zero]) {
    _timer?.cancel();
    state = state.to(DetailsSave.pending);
    _timer = Timer(delay, save);
  }

  /// True once the account has every edit, including any made meanwhile.
  Future<bool> save() async {
    while (true) {
      _timer?.cancel();
      _timer = null;
      final running = _running;
      if (running != null) {
        await running;
        continue;
      }
      if (state.status == DetailsSave.idle) return true;
      final run = _running = _send();
      final ok = await run;
      _running = null;
      if (!ok) return false;
    }
  }

  Future<bool> _send() async {
    state = state.to(DetailsSave.saving);
    try {
      final details = await ref.read(accountDetailsProvider.future);
      final answers = ref.read(profileAnswersProvider);
      await ref.read(profileServiceProvider).saveDetails(details, answers);
    } on Exception {
      state = state.to(DetailsSave.failed);
      return false;
    }
    if (state.status == DetailsSave.saving) {
      state = state.to(DetailsSave.idle, saved: true);
    }
    return true;
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    state = const DetailsSaveState();
  }
}

final detailsSaveProvider =
    NotifierProvider<DetailsSaveNotifier, DetailsSaveState>(
      DetailsSaveNotifier.new,
    );

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
  ref.read(detailsSaveProvider.notifier).reset();
  ref.read(onboardingDraftProvider.notifier).clear();
  await ref.read(accountDetailsProvider.notifier).clear();
  await session.setFirstTipSeen(false);
  await session.setOnboardingDone(false);
  await session.setSignedIn(false);
}
