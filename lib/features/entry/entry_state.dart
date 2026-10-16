import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../data/invite.dart';
import '../avatar/avatar_state.dart';

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

/// A returning account has done onboarding and seen the first tip on
/// another install, so it lands on Discover without either. The name typed
/// at sign-up wins; any other sign-in keeps the account's [name].
Future<void> completeSignIn(
  WidgetRef ref, {
  required bool newAccount,
  String? name,
}) async {
  final session = ref.read(sessionProvider.notifier);
  final draft = ref.read(entryDraftProvider);
  final typed = '${draft.firstName.trim()} ${draft.lastName.trim()}'.trim();
  await session.setSignedIn(true);
  await session.setName(newAccount && typed.isNotEmpty ? typed : name);
  if (newAccount) {
    await ref.read(avatarProvider.notifier).startNewcomer();
  } else {
    await session.setOnboardingDone(true);
    await session.setFirstTipSeen(true);
  }
  ref.read(entryDraftProvider.notifier).clear();
  ref.read(pendingInviteProvider.notifier).clear();
}
