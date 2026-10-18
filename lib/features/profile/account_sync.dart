import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/backend.dart';
import '../../core/flags.dart';
import '../../core/session.dart';
import '../../data/api_client.dart';
import '../../data/live/brief_marks_sync.dart';
import '../../data/live/live_account.dart';
import '../../data/live/live_repository.dart';
import '../../data/live/submit_queue.dart';
import '../../data/local/local_providers.dart';
import '../../data/onboarding_service.dart';
import '../../data/referrals_service.dart' show inviteCodeOutcome;
import '../../router.dart';
import '../discover/discover_state.dart';
import '../drafts/drafts_state.dart';
import '../onboarding/onboarding_draft.dart';
import '../referrals/referrals_state.dart';
import '../submissions/submissions_state.dart';

/// Runs the account's writes in a live build. The outbox sends them for the
/// signed-in person once the session knows the account (at launch and after
/// each sign-in) and stops when the session ends, keeping what waits for
/// that account's next sign-in: a 401 signs the phone out, so the queue
/// holds until then. Only the features the launch runs live make their
/// calls (contract 2 and 8): a preview launch sends nothing, and in a live
/// one the writes of a paused feature wait, kept, for a launch that runs
/// it. The queue waits for the launch's mode to be fixed. First-run
/// answers the API refuses as under 18 take first run back to About you,
/// the way the app shows an under-age date.
final accountSyncProvider = Provider<void>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return;
  final outbox = ref.watch(outboxProvider);
  final mode = ref.watch(liveModeProvider);
  final session = ref.read(sessionProvider.notifier);
  bool signedIn(String userId) => session.scope.userId == userId;
  registerAccountWrites(
    outbox,
    api,
    ref.watch(localStoreProvider),
    live: mode.isLive,
    signedIn: signedIn,
    onFailed: (item, write, code) {
      if (write == AccountWrite.referralApply && ref.mounted) {
        final invite = item.payload['code'];
        if (invite is String) {
          unawaited(
            ref
                .read(unappliedInviteProvider.notifier)
                .keep(item.userId, invite, inviteCodeOutcome(code)),
          );
        }
      }
      if (write == AccountWrite.onboarding &&
          code == 'UNDER_AGE' &&
          signedIn(item.userId) &&
          ref.mounted) {
        unawaited(_refuseDateOfBirth(ref, item.payload['dateOfBirth']));
      }
    },
  );
  registerBriefMarkWrites(
    outbox,
    api,
    live: mode.isLive,
    onRefused: (mark) {
      if (!ref.mounted) return;
      unawaited(switch (mark) {
        BriefMark.saved => ref.read(savedBriefsProvider.notifier).pull(),
        BriefMark.reminder => ref.read(closeRemindersProvider.notifier).pull(),
      });
    },
  );
  registerSubmitWrites(
    outbox,
    api,
    ref.watch(localStoreProvider),
    live: mode.isLive(LiveFeature.uploads),
    onSent: (userId, briefId) {
      if (!signedIn(userId) || !ref.mounted) return;
      unawaited(ref.read(draftsProvider.notifier).discard([briefId]));
      ref.read(mySubmissionsProvider.notifier).refreshQuietly();
    },
  );
  final locked = ref.read(backendProvider.notifier).locked;
  ref.listen(sessionProvider.select((s) => s.signedIn ? s.userId : null), (
    _,
    userId,
  ) {
    if (userId == null || mode.isPreview) {
      unawaited(outbox.stop());
      return;
    }
    final scope = session.scope;
    unawaited(
      locked.then((_) {
        if (scope.open && ref.mounted) return outbox.start(userId);
      }),
    );
  }, fireImmediately: true);
});

/// Keeps the account's writes running for the app's life. They are
/// listened to rather than read, so the mode the splash settles after
/// launch (a first live launch starts as preview) rebuilds them.
void startAccountSync(ProviderContainer container) {
  container
    ..listen(accountSyncProvider, (_, _) {})
    ..listen(outboxOnResumeProvider, (_, _) {});
}

/// The outbox tries again whenever the app comes back to the foreground,
/// and sends what waits out a backoff as soon as the API answers again
/// after the network was gone.
final outboxOnResumeProvider = Provider<void>((ref) {
  final outbox = ref.watch(outboxProvider);
  final resumes = AppLifecycleListener(
    onResume: () => unawaited(outbox.kick()),
  );
  ref.onDispose(resumes.dispose);
  final back = ref
      .watch(apiClientProvider)
      ?.reachable
      .listen((_) => unawaited(outbox.networkBack()));
  ref.onDispose(() => back?.cancel());
});

/// Only while the draft still holds the date that was sent.
Future<void> _refuseDateOfBirth(Ref ref, Object? sent) async {
  final born = ref.read(onboardingDraftProvider).profile.dateOfBirth;
  if (born == null || apiDay(born) != sent) return;
  ref.read(onboardingDraftProvider.notifier).refuseDateOfBirth();
  await ref.read(sessionProvider.notifier).setOnboardingDone(false);
}

/// Set once the first live launch has checked first run against the
/// account.
const firstRunCheckedKey = 'account.firstRunChecked';

/// After the splash of a launch signed in with the profile live: the
/// account's id and name come into the session ([meProvider]), Restore
/// takes over while the account is closing, and the first live launch
/// checks first run ([syncFirstRun]). No answer from the API leaves all of
/// it to the next launch.
Future<void> checkAccountAtLaunch(Reader read, GoRouter router) async {
  // Asked during the splash so Restore can take over at the hand-off; a
  // mode the health check changes before then asks again.
  if (read(sessionProvider).signedIn) read(meProvider.future).ignore();
  await leftSplash(router);
  if (!read(sessionProvider).signedIn) return;
  final scope = read(accountScopeProvider);
  try {
    final me = await read(meProvider.future);
    if (me == null || !scope.open) return;
    if (me.closing && Flags.deleteAccount) {
      router.go(Routes.restoreAccount, extra: me.closesAt);
      return;
    }
    await syncFirstRun(read, me);
  } on Exception catch (error) {
    debugPrint('Account: not checked at launch: $error');
  }
}

/// Completes once [router] is past the splash.
Future<void> leftSplash(GoRouter router) {
  final delegate = router.routerDelegate;
  bool left() {
    final path = delegate.currentConfiguration.uri.path;
    return path.isNotEmpty && path != Routes.splash;
  }

  if (left()) return Future.value();
  final done = Completer<void>();
  void check() {
    if (!left()) return;
    delegate.removeListener(check);
    done.complete();
  }

  delegate.addListener(check);
  return done.future;
}

/// The first launch on the API of a phone that finished first run on the
/// preview: when the account has no record of it, the answers the device
/// still holds go to the account, and with none left first run runs again.
/// Once per install.
Future<void> syncFirstRun(Reader read, Me me) async {
  final prefs = read(sharedPreferencesProvider);
  if (prefs.getBool(firstRunCheckedKey) ?? false) return;
  final session = read(sessionProvider);
  if (session.onboardingDone && me.profile?.onboardingCompletedAt == null) {
    final answers = read(onboardingDraftProvider).profile;
    if (answers.isEmpty) {
      await read(sessionProvider.notifier).setOnboardingDone(false);
    } else {
      await read(onboardingServiceProvider).saveProfile(answers);
    }
  }
  await prefs.setBool(firstRunCheckedKey, true);
}
