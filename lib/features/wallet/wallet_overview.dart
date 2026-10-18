import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../data/models.dart' show WalletTotals;
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/empty_state.dart';
import '../../ui/icon.dart';
import '../../ui/pressable.dart';
import '../../ui/quick_action.dart';
import '../../ui/segmented.dart';
import '../../ui/text_link.dart';
import '../../ui/wallet_card.dart';
import 'wallet_arrives.dart';
import 'wallet_routes.dart';
import 'wallet_rows.dart';
import 'wallet_state.dart';

/// How many rows the Recent activity card holds (37:24 draws seven).
const recentRows = 7;

/// The B5 wallet body: Exp/WalletCard, the quick actions and the recent
/// activity card, or with no activity the shared empty state. On the tab
/// root ([root]) the card carries the eye in its top right corner and the
/// balance tabs (designer answer 19; Figma draws neither, see the spec) and
/// the lens comes from [walletLensProvider]; the On its way and Earned sub
/// pages fix [balance]. A tab shows only for a balance that is not zero,
/// and the control only with two or more.
class WalletOverview extends ConsumerWidget {
  const WalletOverview({
    super.key,
    required this.data,
    this.root = false,
    this.balance,
    this.bottomInset = IqSpace.s6,
  });

  final WalletData data;
  final bool root;
  final IqWalletCardBalance? balance;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lens = ref.watch(walletLensProvider);
    final totals = data.totals;
    final tabs = [
      for (final b in IqWalletCardBalance.values)
        if (_kobo(totals, b) != 0) b,
    ];
    final shown =
        balance ??
        (tabs.isEmpty || tabs.contains(lens.balance)
            ? lens.balance
            : tabs.first);
    final hidden = lens.hidden;
    final now = ref.watch(clockProvider)();
    final briefs = ref.watch(rewardBriefsProvider).value ?? const {};
    final bank = data.savedBank;
    final available = naira(totals.withdrawableKobo);
    final onItsWay = naira(totals.pendingWithdrawalsKobo);
    final earned = naira(totals.totalEarnedKobo);
    final empty = data.activity.isEmpty;
    final rewardsOnly = shown == IqWalletCardBalance.earned;
    final items = [
      for (final item in data.activity)
        if (!rewardsOnly || item.award != null) item,
    ].take(recentRows).toList();

    final card = IqWalletCard(
      balance: shown,
      visibility: hidden
          ? IqWalletCardVisibility.hidden
          : IqWalletCardVisibility.shown,
      amount: switch (shown) {
        IqWalletCardBalance.available => available,
        IqWalletCardBalance.onItsWay => onItsWay,
        IqWalletCardBalance.earned => earned,
      },
      caption: switch (shown) {
        IqWalletCardBalance.available =>
          empty || bank == null
              ? 'Win a brief to start earning'
              : 'Ready to withdraw to ${bank.label}',
        IqWalletCardBalance.onItsWay =>
          'To ${bank?.label ?? ''} · usually arrives in minutes',
        IqWalletCardBalance.earned =>
          'From ${data.winningSubmissions} winning submissions',
      },
      showBreakdown: false,
    );

    final head = <Widget>[
      Stack(
        children: [
          SizedBox(width: double.infinity, child: card),
          if (root)
            Positioned(
              top: IqSpace.s2,
              right: IqSpace.s2,
              child: _Eye(
                hidden: hidden,
                onTap: () =>
                    ref.read(walletLensProvider.notifier).toggleHidden(),
              ),
            ),
        ],
      ),
      if (root && tabs.length > 1) ...[
        const SizedBox(height: IqSpace.s3),
        IqSegmented(
          option1: _tabLabel(tabs[0]),
          option2: _tabLabel(tabs[1]),
          option3: tabs.length > 2 ? _tabLabel(tabs[2]) : null,
          selected: IqSegmentedSelected.values[tabs.indexOf(shown)],
          onChanged: (option) =>
              ref.read(walletLensProvider.notifier).show(tabs[option.index]),
        ),
      ],
      const SizedBox(height: IqSpace.s3),
      Row(
        children: [
          Expanded(
            child: IqQuickAction(
              kind: root && !empty
                  ? IqQuickActionKind.primary
                  : IqQuickActionKind.standard,
              label: 'Withdraw',
              icon: IqIcons.arrow,
              disabled: totals.withdrawableKobo <= 0,
              onTap: () => context.open(Routes.withdraw),
            ),
          ),
          const SizedBox(width: IqSpace.s2),
          Expanded(
            child: IqQuickAction(
              kind: IqQuickActionKind.standard,
              label: 'Bank account',
              icon: IqIcons.bank,
              onTap: () => context.open(bankAccountPath),
            ),
          ),
        ],
      ),
    ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
          sliver: SliverList.list(children: head),
        ),
        if (empty)
          IqSliverEmptyFill(bottom: bottomInset, child: const NoActivity())
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              IqSpace.s4,
              IqSpace.s3,
              IqSpace.s4,
              bottomInset,
            ),
            sliver: SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: motion(context, IqDurations.swap),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                child: ActivityCard(
                  key: ValueKey((rewardsOnly, hidden, items.length)),
                  children: [
                    _Header(
                      title: rewardsOnly ? 'Recent rewards' : 'Recent activity',
                      onSeeAll: () => context.open(
                        activityPath(
                          rewardsOnly ? ActivityTab.rewards : ActivityTab.all,
                        ),
                      ),
                    ),
                    for (final (i, item) in items.indexed)
                      WalletActivityRow(
                        key: ValueKey(item.key),
                        item: item,
                        briefs: briefs,
                        now: now,
                        hidden: hidden,
                        divider: i < items.length - 1,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static int _kobo(WalletTotals totals, IqWalletCardBalance balance) =>
      switch (balance) {
        IqWalletCardBalance.available => totals.withdrawableKobo,
        IqWalletCardBalance.onItsWay => totals.pendingWithdrawalsKobo,
        IqWalletCardBalance.earned => totals.totalEarnedKobo,
      };

  static String _tabLabel(IqWalletCardBalance balance) => switch (balance) {
    IqWalletCardBalance.available => 'Available',
    IqWalletCardBalance.onItsWay => 'On its way',
    IqWalletCardBalance.earned => 'Earned',
  };
}

/// The activity-header of the card: 48 tall (25 with no link), the title
/// in Mob/Body strong fg2 and See all.
class _Header extends StatelessWidget {
  const _Header({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final link = onSeeAll != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(IqSpace.s4, IqSpace.s1, IqSpace.s2, 0),
      child: SizedBox(
        height: link ? 44 : 21,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                style: IqText.bodyStrong.copyWith(color: IqColors.fg2),
              ),
            ),
            if (link)
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80),
                child: IqTextLink(
                  label: 'See all',
                  showIcon: false,
                  onTap: onSeeAll,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A wallet with nothing on it yet: the shared empty state over the
/// wallet illustration, in place of the activity card (owner, 17 Oct).
class NoActivity extends StatelessWidget {
  const NoActivity({super.key});

  @override
  Widget build(BuildContext context) {
    return const IqEmptyState(
      art: WalletArrives(),
      title: 'No activity yet',
      body: 'Rewards and withdrawals land here.',
    );
  }
}

/// The eye that hides the figures (designer answer 19).
class _Eye extends StatelessWidget {
  const _Eye({required this.hidden, required this.onTap});

  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      semanticLabel: hidden ? 'Show balance' : 'Hide balance',
      haptic: IqHaptics.select,
      builder: (context, pressed) => AnimatedOpacity(
        duration: pressed ? IqDurations.dim : IqDurations.release,
        opacity: pressed ? IqOpacity.pressed : 1,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: IqIcon(
              hidden ? IqIcons.eyeOff : IqIcons.eye,
              size: 20,
              color: IqColors.fg2,
            ),
          ),
        ),
      ),
    );
  }
}
