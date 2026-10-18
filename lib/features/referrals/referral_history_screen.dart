import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../core/relative_time.dart';
import '../../data/referrals_service.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/empty_state.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/list_row.dart';
import '../more/more_widgets.dart';
import 'referrals_screen.dart';
import 'referrals_state.dart';
import '../splash/patch_dialog.dart' show IqPageLoading;

/// B20 · Referral history (430:19239) and empty (430:19331): invited,
/// joined and the referral rewards earned, then one row per friend. While
/// referrals pay (contract 12.3) the rows say what each reward paid, and a
/// person who joined with a friend's code sees their own reward first;
/// while they pay nothing the third figure counts the friends who won.
class ReferralHistoryScreen extends ConsumerWidget {
  const ReferralHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referrals = ref.watch(referralsProvider).value;
    final terms = ref.watch(referralTermsProvider);
    final rewards = terms != null;
    final earned = rewards ? ref.watch(referralEarnedProvider).value ?? 0 : 0;
    final now = ref.watch(clockProvider)();
    final invites = referrals?.invites ?? const <Invite>[];
    final inviter = referrals?.invitedBy;
    final own = rewards ? referrals?.invitedByReward : null;
    return SubPage(
      title: 'Referral history',
      body: referrals == null
          ? const IqPageLoading()
          : invites.isEmpty && own == null
          ? const IqEmptyFill(
              child: IqEmptyState(
                figure: IqFigures.sender,
                title: 'No invites yet',
                body: 'Share your code and the friends who join show up here.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
              children: [
                _Summary(
                  stats: [
                    ('${invites.length}', 'Invited'),
                    ('${referrals.joined}', 'Joined'),
                    rewards
                        ? (naira(earned), 'Earned')
                        : ('${referrals.won}', 'Won'),
                  ],
                ),
                const SizedBox(height: IqSpace.s2),
                if (own != null && inviter != null)
                  IqListRow(
                    label: '$inviter invited you',
                    description: own.paid
                        ? 'Won a first brief · '
                              '${rewardPool(own.amountKobo)} paid to you'
                        : own.status == ReferralRewardStatus.pending
                        ? 'Joined ${_ago(referrals.memberSince, now)} · '
                              'no win yet'
                        : 'Won a first brief',
                    icon: own.status == ReferralRewardStatus.pending
                        ? IqIcons.clock
                        : IqIcons.success,
                    divider: invites.isNotEmpty,
                  ),
                for (final (i, invite) in invites.indexed)
                  IqListRow(
                    label: invite.name,
                    description: _line(invite, now, terms: terms),
                    icon: switch (invite.status) {
                      InviteStatus.won => IqIcons.success,
                      InviteStatus.joined => IqIcons.clock,
                      InviteStatus.invited => IqIcons.mail,
                    },
                    divider: i < invites.length - 1,
                  ),
              ],
            ),
      actions: [
        IqButton(
          label: 'Invite friends',
          showIcon: false,
          width: double.infinity,
          onTap: referrals == null
              ? null
              : () => showInviteSheet(context, referrals.code),
        ),
      ],
    );
  }

  /// A won friend's line names the reward it paid: the API's own amount
  /// once paid, the preview's ₦500; nothing while it is pending, capped or
  /// not owed, or while referrals pay nothing.
  static String _line(
    Invite invite,
    DateTime now, {
    required ReferralTerms? terms,
  }) => switch (invite.status) {
    InviteStatus.won => switch (terms == null
        ? null
        : invite.reward == null
        ? (terms.earnedKobo == null ? terms.inviterReward : null)
        : invite.reward!.paid
        ? rewardPool(invite.reward!.amountKobo)
        : null) {
      final paid? => 'Won a first brief · $paid paid to you',
      null => 'Won a first brief',
    },
    InviteStatus.joined => 'Joined ${_ago(invite.at ?? now, now)} · no win yet',
    InviteStatus.invited => 'Invited · has not joined',
  };
}

/// "2 weeks ago" from a week on, else as the product writes it.
String _ago(DateTime at, DateTime now) {
  final days = now.difference(at).inDays;
  if (days < 7) return timeAgo(at, now);
  final weeks = (days / 7).round();
  return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
}

class _Summary extends StatelessWidget {
  const _Summary({required this.stats});

  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 17),
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IqColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final (value, label) in stats)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: IqText.figureSmall.copyWith(color: IqColors.fg),
                ),
                const SizedBox(height: 1),
                Text(
                  label.toUpperCase(),
                  style: IqText.mono.copyWith(color: IqColors.fg2),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
