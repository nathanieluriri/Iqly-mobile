import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../data/models.dart';
import '../../data/referrals_service.dart';
import '../../data/repository.dart';
import '../wallet/wallet_state.dart';

class ReferralsNotifier extends AsyncNotifier<Referrals> {
  @override
  Future<Referrals> build() => ref.watch(referralsServiceProvider).referrals();

  Future<InviteCodeResult> apply(String code) async {
    final result = await ref.read(referralsServiceProvider).applyCode(code);
    final inviter = result.inviter;
    final current = state.value;
    if (inviter != null && current != null) {
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
  return !won && now.difference(referrals.memberSince).inDays < 7;
});
