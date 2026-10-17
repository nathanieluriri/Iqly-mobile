import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/backend.dart';
import '../../core/motion.dart';
import '../../core/session.dart';
import '../../data/api_client.dart';
import '../../data/auth.dart';
import '../../data/local/local_providers.dart';
import '../../data/reference_data.dart';
import '../../router.dart';
import '../avatar/avatar_state.dart';
import '../../surfaces/push.dart';
import '../onboarding/onboarding_sheets.dart';
import '../outcomes/outcomes_state.dart';
import '../profile/profile_state.dart';

const _live = 'live';
const _preview = 'preview';

/// The sheet Try notifications opens when its mode row is held: Live or
/// Preview. Picking the other mode switches to it ([switchLaunchMode]).
Future<void> pickLaunchMode(BuildContext context, WidgetRef ref) async {
  final backend = ref.read(backendProvider.notifier);
  if (!backend.canForce) return;
  IqHaptics.hold.play();
  final current = ref.read(backendProvider).isPreview ? _preview : _live;
  final picked = await showOnboardingSheet<String>(
    context,
    (context) => OptionSheet(
      title: 'Mode',
      options: const [RefOption(_live, 'Live'), RefOption(_preview, 'Preview')],
      selected: current,
    ),
    hug: true,
  );
  if (picked == null || picked == current || !context.mounted) return;
  await switchLaunchMode(
    ref.read,
    GoRouter.of(context),
    preview: picked == _preview,
  );
}

/// Signs the person out and forgets everything this phone keeps for the
/// account (cache, outbox, drafts, saved briefs, reminders, tokens and its
/// local rows), keeps [preview] for every launch from now on, and starts
/// again at the splash. Live still runs only once health says the API is
/// ready; until then the launch stays in preview as any other would.
Future<void> switchLaunchMode(
  Reader read,
  GoRouter router, {
  required bool preview,
}) async {
  final session = read(sessionProvider);
  final users = {session.userId, session.lostUserId}.nonNulls;
  unawaited(read(outboxProvider).stop());
  if (session.signedIn) {
    try {
      await read(pushProvider)?.signingOut();
      await read(authServiceProvider).signOut();
    } on Object catch (error) {
      // The device forgets the account below whatever the API answered.
      debugPrint('Mode switch: sign-out not confirmed: $error');
    }
  }
  await read(apiClientProvider)?.tokens.clear();
  await forgetSession(read);
  final store = read(localStoreProvider);
  for (final user in users) {
    await store.wipeUser(user);
    await read(avatarProvider.notifier).wipe(user);
  }
  await read(sharedPreferencesProvider).remove(celebratedKey);
  await read(backendProvider.notifier).force(preview: preview);
  router.go(Routes.splash);
}
