import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/referrals_service.dart';
import '../../data/repository.dart';
import '../wallet/wallet_state.dart';

class ReferralsNotifier extends AsyncNotifier<Referrals> {
  @override
  Future<Referrals> build() => ref.watch(referralsServiceProvider).referrals();

  /// An answer that lands once its account is no longer signed in shows
  /// on no one's referrals.
  Future<InviteCodeResult> apply(String code) async {
    final scope = ref.read(accountScopeProvider);
    final result = await ref.read(referralsServiceProvider).applyCode(code);
    final inviter = result.inviter;
    final current = state.value;
    if (scope.open && inviter != null && current != null) {
      state = AsyncData(current.withInviter(inviter));
    }
    return result;
  }
}

final referralsProvider = AsyncNotifierProvider<ReferralsNotifier, Referrals>(
  ReferralsNotifier.new,
);

/// The ₦500 referral rewards the wallet holds, "Earned" on Referral history.
final referralEarnedProvider = FutureProvider<int>((ref) async {
  final wallet = await ref.watch(walletProvider.future);
  return referralEarnedKobo(wallet.ledger);
});

/// "Enter an invite code" shows until the first win or 7 days after sign-up,
/// whichever comes first (designer answer 41), and never once a code is in.
final inviteCodeOpenProvider = FutureProvider<bool>((ref) async {
  final referrals = await ref.watch(referralsProvider.future);
  if (referrals.invitedBy != null) return false;
  final submissions = await ref.watch(repositoryProvider).submissions();
  final won = submissions.any((s) => s.status == SubmissionStatus.winner);
  final now = ref.watch(clockProvider)();
  final until = referrals.applyUntil;
  if (until != null && !now.isBefore(until)) return false;
  return !won && now.difference(referrals.memberSince).inDays < 7;
});

/// A friend's code from an invite link that the account refused after
/// sign-up, kept for the account so Referrals can say so and offer it again.
class UnappliedInvite {
  const UnappliedInvite(this.code, this.outcome);

  final String code;
  final InviteCodeOutcome outcome;
}

class UnappliedInviteNotifier extends Notifier<UnappliedInvite?> {
  static String key(String userId) => 'referrals.unapplied.$userId';

  @override
  UnappliedInvite? build() {
    final user = ref.watch(accountProvider);
    if (user == null) return null;
    final raw = ref.watch(sharedPreferencesProvider).getString(key(user));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map;
      final outcome = InviteCodeOutcome.values.asNameMap()[json['outcome']];
      final code = json['code'];
      return code is String
          ? UnappliedInvite(code, outcome ?? InviteCodeOutcome.unknown)
          : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> keep(String userId, String code, InviteCodeOutcome outcome) =>
      ref
          .read(sharedPreferencesProvider)
          .setString(
            key(userId),
            jsonEncode({'code': code, 'outcome': outcome.name}),
          )
          .then((_) => ref.invalidateSelf());

  Future<void> clear() async {
    final user = ref.read(accountProvider);
    if (user == null) return;
    await ref.read(sharedPreferencesProvider).remove(key(user));
    ref.invalidateSelf();
  }
}

final unappliedInviteProvider =
    NotifierProvider<UnappliedInviteNotifier, UnappliedInvite?>(
      UnappliedInviteNotifier.new,
    );
