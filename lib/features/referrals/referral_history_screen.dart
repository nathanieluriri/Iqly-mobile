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

/// B20 · Referral history (430:19239) and empty (430:19331): invited,
/// joined and the referral rewards earned (the wallet's ledger rows), then
/// one row per friend. Live referrals pay nothing yet, so the third figure
/// counts the friends who won instead.
class ReferralHistoryScreen extends ConsumerWidget {
  const ReferralHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referrals = ref.watch(referralsProvider).value;
    final rewards = ref.watch(referralRewardsProvider);
    final earned = rewards ? ref.watch(referralEarnedProvider).value ?? 0 : 0;
    final now = ref.watch(clockProvider)();
    final invites = referrals?.invites ?? const <Invite>[];
    return SubPage(
      title: 'Referral history',
      body: referrals == null
          ? const SizedBox.shrink()
          : invites.isEmpty
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
                for (final (i, invite) in invites.indexed)
                  IqListRow(
                    label: invite.name,
                    description: _line(invite, now, rewards: rewards),
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

  static String _line(Invite invite, DateTime now, {required bool rewards}) =>
      switch (invite.status) {
        InviteStatus.won =>
          rewards
              ? 'Won a first brief · ${referralReward()} paid to you'
              : 'Won a first brief',
        InviteStatus.joined =>
          'Joined ${_ago(invite.at ?? now, now)} · no win yet',
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
