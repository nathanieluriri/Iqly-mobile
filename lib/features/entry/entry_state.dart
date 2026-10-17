import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend.dart';

import '../../core/flags.dart';
import '../../core/session.dart';
import '../../data/auth.dart';
import '../../data/invite.dart';
import '../../data/live/live_account.dart';
import '../../data/live/live_repository.dart' show liveModeProvider;
import '../../data/referrals_service.dart' show referralsServiceProvider;
import '../../router.dart';
import '../avatar/avatar_state.dart';
import '../onboarding/onboarding_draft.dart';
import '../profile/profile_state.dart';

class EntryDraft {
  const EntryDraft({this.email = '', this.firstName = '', this.lastName = ''});

  final String email;
  final String firstName;
  final String lastName;
}

/// What the entry screens hand each other: the email typed on the landing
/// and the name from sign-up. The password never leaves its screen.
class EntryDraftNotifier extends Notifier<EntryDraft> {
  @override
  EntryDraft build() => const EntryDraft();

  void setEmail(String email) => state = EntryDraft(
    email: email,
    firstName: state.firstName,
    lastName: state.lastName,
  );

  void setName(String firstName, String lastName) => state = EntryDraft(
    email: state.email,
    firstName: firstName,
    lastName: lastName,
  );

  void clear() => state = const EntryDraft();
}

final entryDraftProvider = NotifierProvider<EntryDraftNotifier, EntryDraft>(
  EntryDraftNotifier.new,
);

/// The invite an invite link opened the app with, until sign up uses it or
/// the person signs in instead (answer 22).
class PendingInviteNotifier extends Notifier<Invite?> {
  @override
  Invite? build() => null;

  /// Looks [code] up and keeps the invite when it is known.
  Future<void> accept(String code) async {
    final invite = await ref.read(inviteServiceProvider).lookUp(code);
    if (invite != null) state = invite;
  }

  void clear() => state = null;
}

final pendingInviteProvider = NotifierProvider<PendingInviteNotifier, Invite?>(
  PendingInviteNotifier.new,
);

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isEmail(String value) => _email.hasMatch(value.trim());

const minPasswordLength = 8;

/// Where the app goes once signed in, and what that route takes.
typedef SignInLanding = ({String route, Object? extra});

/// A returning account has done onboarding and seen the first tip on
/// another install, so it lands on Discover without either. The name typed
/// at sign-up wins; any other sign-in keeps the account's [name]. [userId]
/// keys the person's rows in the local store from the start. What a lost
/// session left on the phone is its account's again when [userId] is that
/// account, first run where it left off included; for anyone else the
/// phone first forgets it, as sign out would. Answers where to go: Restore
/// while the account is closing (live builds ask `GET /me`), else first run
/// for a new account and Discover for a returning one.
Future<SignInLanding> completeSignIn(
  WidgetRef ref, {
  required bool newAccount,
  String? name,
  String? userId,
}) async {
  final session = ref.read(sessionProvider.notifier);
  final lost = ref.read(sessionProvider).lostUserId;
  final back = lost != null && lost == userId;
  if (lost != null && !back) await forgetSession(ref.read);
  final draft = ref.read(entryDraftProvider);
  final typed = '${draft.firstName.trim()} ${draft.lastName.trim()}'.trim();
  if (userId != null) await session.setUserId(userId);
  await session.setSignedIn(true);
  if (back) await session.setLostUserId(null);
  await session.setName(newAccount && typed.isNotEmpty ? typed : name);
  if (newAccount) {
    if (!back) await ref.read(avatarProvider.notifier).startNewcomer();
  } else {
    await session.setOnboardingDone(true);
    await session.setFirstTipSeen(true);
  }
  final invite = ref.read(pendingInviteProvider);
  if (newAccount && invite != null && _appliesInvites(ref)) {
    unawaited(_applyInvite(ref, invite.code));
  }
  ref.read(entryDraftProvider.notifier).clear();
  ref.read(pendingInviteProvider.notifier).clear();
  final me = await _signedInAccount(ref);
  if (me != null && me.closing && Flags.deleteAccount) {
    return (route: Routes.restoreAccount, extra: me.closesAt);
  }
  final String route;
  if (!newAccount) {
    route = Routes.home;
  } else if (back) {
    route =
        onboardingLaunchRoute(
          ref.read(sessionProvider),
          ref.read(onboardingDraftProvider),
        ) ??
        Routes.home;
  } else {
    route = Routes.onboarding;
  }
  return (route: route, extra: null);
}

/// Only the API keeps a friend's code; the preview's sign-up takes it as
/// it always has.
bool _appliesInvites(WidgetRef ref) =>
    ref.read(liveModeProvider).isLive(LiveFeature.referrals);

/// The code an invite link brought, added to the new account. The person
/// can still add it on Referrals if this does not land.
Future<void> _applyInvite(WidgetRef ref, String code) async {
  try {
    await ref.read(referralsServiceProvider).applyCode(code);
  } on Object catch (error) {
    debugPrint('Invite code not added: $error');
  }
}

Future<Me?> _signedInAccount(WidgetRef ref) async {
  try {
    return await ref.read(meProvider.future).timeout(AuthTiming.closingCheck);
  } on Exception {
    return null;
  }
}
