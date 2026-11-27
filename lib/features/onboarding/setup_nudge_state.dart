import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../data/api_client.dart';
import '../../data/live/live_account.dart';
import '../../data/live/live_profile_service.dart';
import 'onboarding_draft.dart';

enum SetupNudgeStatus {
  pendingFirstRun,
  pendingUnderAge,
  pendingPartial,
  pendingServerIncomplete,
  complete,
}

class SetupNudgeState {
  const SetupNudgeState({
    required this.status,
    required this.draft,
    required this.stepsLeft,
    required this.firstIncomplete,
  });

  final SetupNudgeStatus status;
  final OnboardingDraft draft;
  final int stepsLeft;
  final OnboardingStep? firstIncomplete;

  bool get visible => status != SetupNudgeStatus.complete;
}

SetupNudgeState resolveSetupNudge({
  required SessionState session,
  required OnboardingDraft draft,
  ContributorProfile? server,
  List<Map<String, dynamic>> pendingWrites = const [],
}) {
  final effective = draft.copyWith(
    profile: mergeOnboardingProfile(draft.profile, server, pendingWrites),
  );
  final left = effective.stepsLeft;
  final SetupNudgeStatus status;
  if (draft.underAge) {
    status = SetupNudgeStatus.pendingUnderAge;
  } else if (server?.onboardingCompletedAt != null) {
    status = SetupNudgeStatus.complete;
  } else if (!session.onboardingDone) {
    status = SetupNudgeStatus.pendingFirstRun;
  } else if (left > 0 && (draft.started || server != null)) {
    status = server == null
        ? SetupNudgeStatus.pendingPartial
        : SetupNudgeStatus.pendingServerIncomplete;
  } else {
    status = SetupNudgeStatus.complete;
  }
  return SetupNudgeState(
    status: status,
    draft: effective,
    stepsLeft: left,
    firstIncomplete: effective.firstIncomplete,
  );
}

final pendingOnboardingWritesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final link = ref.watch(accountLinkProvider);
      final user = ref.watch(accountProvider);
      if (link == null || user == null) return const [];
      return [
        ...await link.waiting(AccountWrite.onboarding),
        ...await link.waiting(AccountWrite.profile),
      ];
    });

final setupNudgeStateProvider = Provider<SetupNudgeState>((ref) {
  final session = ref.watch(sessionProvider);
  final draft = ref.watch(onboardingDraftProvider);
  final server = ref.watch(meProvider).value?.profile;
  final pending = ref.watch(pendingOnboardingWritesProvider).value ?? const [];
  final state = resolveSetupNudge(
    session: session,
    draft: draft,
    server: server,
    pendingWrites: pending,
  );

  if (server != null) {
    Future.microtask(() {
      if (!ref.mounted || ref.read(accountProvider) != session.userId) return;
      ref
          .read(onboardingDraftProvider.notifier)
          .reconcileServer(server, pending);
    });
  }
  if (state.status == SetupNudgeStatus.complete && !session.onboardingDone) {
    Future.microtask(() {
      if (ref.mounted && ref.read(accountProvider) == session.userId) {
        unawaited(ref.read(sessionProvider.notifier).setOnboardingDone(true));
      }
    });
  }
  return state;
});

/// Exists only while setup still needs work. Connectivity recovery asks the
/// account cache to refresh; Riverpod disposes this listener at completion.
final setupNudgeRefreshProvider = Provider<void>((ref) {
  final visible = ref.watch(
    setupNudgeStateProvider.select((state) => state.visible),
  );
  if (!visible) return;
  final api = ref.watch(apiClientProvider);
  if (api == null) return;
  final subscription = api.reachable.listen((_) {
    unawaited(refreshAccountIfStale(ref));
  });
  ref.onDispose(subscription.cancel);
});
