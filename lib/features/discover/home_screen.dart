import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/responsive.dart';
import '../../core/session.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/brand_bubble.dart';
import '../../ui/button.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/list_row.dart';
import '../../ui/pull_indicator.dart';
import '../../ui/section_title.dart';
import '../../ui/skeleton.dart';
import '../../ui/ticket_card.dart';
import '../onboarding/setup_nudge.dart';
import '../withdrawals/payout_arrival.dart';
import 'app_shell.dart';
import 'discover_state.dart';
import 'discover_widgets.dart';

/// B1 · Discover · Home (31:24) with the B12 For you behaviour (192:8644):
/// open polls, activations, Closing soon, the interest groups, then More
/// briefs, loaded a page at a time. Pull to refresh shows Exp/PullIndicator
/// above the chips; the first load shows skeletons; a failed load shows the
/// error banner; an empty feed shows the trophy.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const double _loadMoreWithin = 240;

  final _scroll = ScrollController();
  double _pull = 0;
  bool _armed = false;
  Timer? _doneTimer;

  @override
  void dispose() {
    _doneTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final metrics = n.metrics;
    if (n is ScrollUpdateNotification) {
      final dragging = n.dragDetails != null;
      final over = -metrics.pixels;
      if (dragging) {
        setState(() {
          _pull = over > 0 ? over : 0;
          _armed = over >= IqPullIndicator.fadeDistance;
        });
      } else if (_armed) {
        _armed = false;
        _refresh();
      }
      if (_pull > 0 && !dragging && over <= 0) setState(() => _pull = 0);
    }
    if (n is ScrollEndNotification) {
      if (_armed) {
        _armed = false;
        _refresh();
      }
      if (_pull != 0) setState(() => _pull = 0);
    }
    if (metrics.extentAfter < _loadMoreWithin) _maybeLoadMore();
    return false;
  }

  void _maybeLoadMore() {
    final data = ref.read(discoverFeedProvider).value;
    if (data == null || data.loadingMore) return;
    final view = _view(data);
    if (view.hasMore) ref.read(discoverFeedProvider.notifier).loadMore();
  }

  Future<void> _refresh() async {
    setState(() => _pull = 0);
    await ref.read(discoverFeedProvider.notifier).refresh();
    if (!mounted) return;
    _doneTimer?.cancel();
    _doneTimer = Timer(
      IqPullIndicator.doneHold,
      () => ref.read(discoverFeedProvider.notifier).settleRefresh(),
    );
  }

  FeedView _view(FeedData data) => buildFeed(
    briefs: data.briefs,
    filters: ref.read(discoverFiltersProvider),
    interests: ref.read(feedInterestsProvider),
    now: ref.read(clockProvider)(),
    window: data.window,
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(discoverFiltersProvider, (previous, next) {
      ref.read(discoverFeedProvider.notifier).resetWindow();
    });
    final feed = ref.watch(discoverFeedProvider);
    final filters = ref.watch(discoverFiltersProvider);
    ref.watch(feedInterestsProvider);
    final data = feed.value;

    final List<Widget> body;
    if (data != null) {
      body = _feed(data, _view(data));
    } else if (feed.hasError) {
      body = _failed();
    } else {
      body = _loading();
    }

    final refresh = data?.refresh ?? RefreshPhase.idle;
    final timeLabel = data?.refreshedAt == null
        ? ''
        : DateFormat('H:mm').format(data!.refreshedAt!);

    return Scaffold(
      backgroundColor: IqColors.bg,
      body: SafeArea(
        bottom: false,
        child: CenteredContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DiscoverTopBar(),
              Expanded(
                child: Stack(
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: _onScroll,
                      child: ListView(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.only(
                          bottom: AppShell.contentInset(context),
                        ),
                        children: gapped([
                          if (refresh != RefreshPhase.idle)
                            _inset(
                              IqPullIndicator(
                                state: refresh == RefreshPhase.refreshing
                                    ? IqPullIndicatorState.refreshing
                                    : IqPullIndicatorState.done,
                                doneLabel: 'Up to date · $timeLabel',
                              ),
                            ),
                          FeedChips(
                            selected: filters.forYou
                                ? FeedChip.forYou
                                : FeedChip.all,
                          ),
                          if (ref.watch(recentPayoutProvider)
                              case final payout?)
                            _inset(PayoutArrivalRow(payout: payout)),
                          ..._nudge(),
                          ...body,
                        ]),
                      ),
                    ),
                    if (_pull > 0)
                      Positioned(
                        top: 0,
                        left: IqSpace.s4,
                        right: IqSpace.s4,
                        child: IqPullIndicator(
                          pullExtent: (_pull / IqPullIndicator.fadeDistance)
                              .clamp(0.0, 1.0),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Iterable<Widget> _nudge() sync* {
    if (!ref.watch(sessionProvider.select((s) => s.onboardingDone))) {
      yield _inset(const SetupNudge());
    }
  }

  List<Widget> _loading() => [
    for (final kind in const [
      IqSkeletonKind.ticket,
      IqSkeletonKind.ticket,
      IqSkeletonKind.row,
      IqSkeletonKind.ticket,
    ])
      _inset(IqSkeleton(kind: kind)),
  ];

  List<Widget> _failed() => [
    _inset(
      IqBanner(
        kind: IqBannerKind.error,
        title: 'Couldn’t load. Check your connection.',
        action: 'Try again',
        onAction: () => ref.read(discoverFeedProvider.notifier).retry(),
      ),
    ),
    ..._proposals(),
    _inset(
      _EmptyText(
        title: 'Nothing to show yet',
        body: 'They will show here once they load.',
      ),
    ),
  ];

  /// Open polls and the Activations row, each behind its flag.
  List<Widget> _proposals() {
    final brands = Flags.polls
        ? ref.watch(pollBrandsProvider).value ?? const []
        : const [];
    final activations = Flags.activations
        ? ref.watch(activationsSummaryProvider).value
        : null;
    return [
      if (brands.isNotEmpty) ...[
        _inset(
          IqSectionTitle(
            title: 'Open polls',
            count: '${brands.length}',
            onSeeAll: () => context.push(Routes.polls),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: gappedRow([
              for (final brand in brands)
                IqBrandBubble(
                  initial: brand.initial,
                  name: brand.businessName,
                  count: '${brand.unanswered}',
                  state: brand.allAnswered
                      ? IqBrandBubbleState.done
                      : IqBrandBubbleState.newPolls,
                  onTap: () => context.push(
                    Uri(
                      path: Routes.polls,
                      queryParameters: {'business': brand.businessName},
                    ).toString(),
                  ),
                ),
            ]),
          ),
        ),
      ],
      if (activations != null)
        _inset(
          IqListRow(
            label: 'Activations',
            description: '${activations.closingToday} closes today',
            showDescription: activations.closingToday > 0,
            icon: IqIcons.timer,
            divider: false,
            onTap: () => context.push(Routes.activations),
          ),
        ),
    ];
  }

  List<Widget> _feed(FeedData data, FeedView view) {
    final filters = ref.read(discoverFiltersProvider);
    if (view.isEmpty) {
      return [
        ..._proposals(),
        _inset(
          const _EmptyText(
            illustration: IqIllustrations.trophy,
            title: 'No open briefs right now',
            body: 'New briefs land here.',
          ),
        ),
      ];
    }
    void openFilters() => context.go(Routes.filters);
    return [
      ..._proposals(),
      if (view.closingSoon.isNotEmpty) ...[
        _inset(
          IqSectionTitle(
            title: 'Closing soon',
            count: '${view.closingSoon.length}',
            onSeeAll: openFilters,
          ),
        ),
        SizedBox(
          height: 188,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
            itemCount: view.closingSoon.length,
            separatorBuilder: (context, i) => const SizedBox(width: IqSpace.s3),
            itemBuilder: (context, i) => BriefTicket(
              brief: view.closingSoon[i],
              kind: IqTicketCardKind.hero,
            ),
          ),
        ),
      ],
      for (final (i, group) in view.groups.indexed) ...[
        _inset(
          IqSectionTitle(
            title: group.title,
            count: '${group.total}',
            showLink: i == 0,
            link: 'Filter',
            onSeeAll: () => context.go(Routes.profile),
          ),
        ),
        for (final brief in group.briefs) _ticket(BriefTicket(brief: brief)),
      ],
      if (view.more.total > 0) ...[
        _inset(
          IqSectionTitle(
            title: view.more.title,
            count: '${view.more.total}',
            link: 'Filter',
            onSeeAll: openFilters,
          ),
        ),
        for (final brief in view.more.briefs)
          _ticket(BriefTicket(brief: brief)),
      ],
      if (data.loadingMore) ...[
        _inset(const IqSkeleton()),
        _inset(
          Text(
            'Loading more'.toUpperCase(),
            style: IqText.mono.copyWith(color: IqColors.fg3),
          ),
        ),
      ] else if (!view.hasMore) ...[
        _inset(
          Text(
            'That’s all ${view.total} ${filters.status.label.toLowerCase()} briefs',
            textAlign: TextAlign.center,
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
        ),
        _inset(
          IqButton(
            label: 'Adjust interests',
            kind: IqButtonKind.ghost,
            showIcon: false,
            width: double.infinity,
            onTap: () => context.go(Routes.profile),
          ),
        ),
      ],
    ];
  }

  Widget _ticket(Widget ticket) => Center(child: ticket);
}

Widget _inset(Widget child) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
  child: child,
);

List<Widget> gappedRow(Iterable<Widget> items) {
  final out = <Widget>[];
  for (final item in items) {
    if (out.isNotEmpty) out.add(const SizedBox(width: IqSpace.s3));
    out.add(item);
  }
  return out;
}

/// The empty and failed feed: an optional illustration, a card title and
/// one line.
class _EmptyText extends StatelessWidget {
  const _EmptyText({
    required this.title,
    required this.body,
    this.illustration,
  });

  final String title;
  final String body;
  final IqIllustrations? illustration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: IqSpace.s6),
      child: Column(
        children: [
          if (illustration != null) ...[
            IqIllustration(illustration!),
            const SizedBox(height: IqSpace.s2),
          ],
          SizedBox(
            width: double.infinity,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: IqText.cardTitle.copyWith(color: IqColors.fg),
            ),
          ),
          const SizedBox(height: IqSpace.s2),
          SizedBox(
            width: double.infinity,
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: IqText.body.copyWith(color: IqColors.fg2),
            ),
          ),
        ],
      ),
    );
  }
}
