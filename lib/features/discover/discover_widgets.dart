import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brief_labels.dart';
import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/money.dart';
import '../../core/transitions.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/bookmark.dart';
import '../../ui/chip.dart';
import '../../ui/ticket_card.dart';
import '../../ui/top_bar.dart';
import '../onboarding/onboarding_draft.dart';
import 'discover_state.dart';

/// Exp/TopBar Home: greeting, "Discover" and the bell with the unread count.
/// The greeting names the person by the first name typed at sign-up on this
/// device, else the account's.
class DiscoverTopBar extends ConsumerWidget {
  const DiscoverTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    final now = ref.watch(clockProvider)();
    return IqTopBar(
      greeting: greeting(now, ref.watch(greetingNameProvider)),
      title: 'Discover',
      count: '$unread',
      showCount: unread > 0,
      onBell: () => context.push(Routes.notifications),
      showWallet: false,
      showGreeting: true,
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
      onTap: () => context.push(Routes.brief(brief.id), extra: brief),
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
