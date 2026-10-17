import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brief_labels.dart';
import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/money.dart';
import '../../core/navigation.dart';
import '../../core/transitions.dart';
import '../../data/models.dart';
import '../../data/referrals_service.dart' show referralsShownProvider;
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/bookmark.dart';
import '../../ui/brief_card.dart';
import '../../ui/chip.dart';
import '../../ui/meta.dart';
import '../../ui/ticket_card.dart';
import '../../ui/top_bar.dart';
import 'business_art.dart';
import 'discover_state.dart';

/// Exp/TopBar Home: "Discover", the gift and the bell with the unread
/// count. [giftShine] runs the gift's one shine. The gift opens Referrals,
/// which a live launch does not have yet, so there it goes.
class DiscoverTopBar extends ConsumerWidget {
  const DiscoverTopBar({super.key, this.giftShine = false});

  final bool giftShine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    return IqTopBar(
      title: 'Discover',
      count: '$unread',
      showCount: unread > 0,
      showWallet: false,
      showGift: ref.watch(referralsShownProvider),
      giftTwinkle: giftShine,
      onGift: () => context.open(Routes.referrals),
      onBell: () => context.open(Routes.notifications),
    );
  }
}

enum FeedChip { forYou, all, saved }

void browseForYou(BuildContext context, WidgetRef ref) {
  ref.read(discoverFiltersProvider.notifier).showForYou();
  context.go(Routes.home);
}

/// The feed lens row: For you, All and (behind Flags.savedBriefs) Saved.
/// Each tap crosses the content under the chips into the picked lens while
/// the chips hold still (spec 3.7).
class FeedChips extends ConsumerWidget {
  const FeedChips({super.key, required this.selected});

  final FeedChip selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void pick(FeedChip chip) {
      if (chip == selected) return;
      final filters = ref.read(discoverFiltersProvider.notifier);
      LensCrossfade.cross(context, line: context);
      switch (chip) {
        case FeedChip.forYou:
          filters.showForYou();
          context.go(Routes.home);
        case FeedChip.all:
          filters.showAll();
          context.go(Routes.home);
        case FeedChip.saved:
          context.go(Routes.savedBriefs);
      }
    }

    Widget chip(FeedChip chip, String label) => IqChip(
      label: label,
      state: chip == selected ? IqChipState.selected : IqChipState.standard,
      onChanged: (_) => pick(chip),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      child: Wrap(
        spacing: IqSpace.s2,
        runSpacing: IqSpace.s2,
        children: [
          chip(FeedChip.forYou, 'For you'),
          chip(FeedChip.all, 'All'),
          if (Flags.savedBriefs) chip(FeedChip.saved, 'Saved'),
        ],
      ),
    );
  }
}

/// A brief as an Exp/TicketCard with its live deadline chip, capacity and
/// bookmark. Tapping opens brief detail, handing it the brief so the push
/// draws the page from its first frame.
class BriefTicket extends ConsumerWidget {
  const BriefTicket({
    super.key,
    required this.brief,
    this.kind = IqTicketCardKind.list,
  });

  final Brief brief;
  final IqTicketCardKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final left = timeLeft(brief.deadline, now);
    final closed = !brief.isLive;
    final saved =
        ref.watch(savedBriefsProvider).value?.any((b) => b.id == brief.id) ??
        false;
    return IqTicketCard(
      kind: kind,
      title: brief.title,
      meta: ticketMeta(brief),
      initial: businessInitial(brief),
      reward: rewardPool(brief.rewardPoolKobo),
      rule: brief.winnerRule ?? '',
      showRule: false,
      spots: spotsLeftLabel(brief),
      showSpotsMarker: brief.spotsLeft != null,
      urgency: closesIn(left, closed: closed),
      urgencyTone: urgencyTone(left, closed: closed),
      showBookmark: Flags.savedBriefs,
      bookmarkState: saved ? IqBookmarkState.on : IqBookmarkState.off,
      onBookmarkChanged: (state) => ref
          .read(savedBriefsProvider.notifier)
          .setSaved(brief, state == IqBookmarkState.on),
      onTap: () => context.open(Routes.brief(brief.id), extra: brief),
    );
  }
}

/// The chips a brief card shows: the pool, the time it takes and, while it
/// has one, the deadline (Urgent within 3 days, else plain). Closed briefs
/// read "Closed".
List<Widget> briefMeta(Brief brief, DateTime now) {
  final left = timeLeft(brief.deadline, now);
  final closed = !brief.isLive || (left != null && left <= Duration.zero);
  final minutes = brief.minutes;
  return [
    IqMeta(kind: IqMetaKind.reward, label: rewardShort(brief.rewardPoolKobo)),
    if (minutes != null) IqMeta(kind: IqMetaKind.time, label: '$minutes min'),
    if (closed || left != null)
      IqMeta(
        kind: !closed && left! <= DeadlineRules.closingSoon
            ? IqMetaKind.urgent
            : IqMetaKind.deadline,
        label: closesIn(left, closed: closed),
      ),
  ];
}

/// The business as the product names it: anonymous briefs read "Private
/// business".
String businessLabel(Brief brief) => brief.businessName ?? 'Private business';

/// A brief as an Exp/BriefCard (Feature) with its live deadline and
/// bookmark. Tapping opens brief detail, handing it the brief so the push
/// draws the page from its first frame.
class BriefFeatureCard extends ConsumerWidget {
  const BriefFeatureCard({super.key, required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final saved =
        ref.watch(savedBriefsProvider).value?.any((b) => b.id == brief.id) ??
        false;
    return IqBriefCard(
      kind: IqBriefCardKind.feature,
      brand: businessLabel(brief),
      title: brief.title,
      cover: businessCover(brief.cover),
      logo: businessLogo(brief.logo),
      meta: briefMeta(brief, now),
      closingSoon: isClosingSoon(brief, now),
      showBookmark: Flags.savedBriefs,
      bookmark: saved ? IqBookmarkState.on : IqBookmarkState.off,
      onBookmarkChanged: (state) => ref
          .read(savedBriefsProvider.notifier)
          .setSaved(brief, state == IqBookmarkState.on),
      onTap: () => context.open(Routes.brief(brief.id), extra: brief),
    );
  }
}

/// The lens chips as chrome: pinned under the top bar while the feed scrolls
/// beneath them (B12 192:9179, 192:9334), on paper, with the 12 pt gap to
/// the first item. [chipsKey] finds the row, whose bottom edge a content
/// crossfade starts from.
class PinnedFeedChips extends StatelessWidget {
  const PinnedFeedChips({super.key, required this.selected, this.chipsKey});

  final FeedChip selected;
  final Key? chipsKey;

  @override
  Widget build(BuildContext context) {
    return PinnedHeaderSliver(
      child: ColoredBox(
        color: IqColors.bg,
        child: Padding(
          padding: const EdgeInsets.only(bottom: IqSpace.s3),
          child: FeedChips(key: chipsKey, selected: selected),
        ),
      ),
    );
  }
}

/// Vertical list items 12 apart.
List<Widget> gapped(Iterable<Widget> items, {double gap = IqSpace.s3}) {
  final out = <Widget>[];
  for (final item in items) {
    if (out.isNotEmpty) out.add(SizedBox(height: gap));
    out.add(item);
  }
  return out;
}
