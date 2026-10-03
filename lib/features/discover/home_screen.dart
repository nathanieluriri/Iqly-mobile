import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/session.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/brand_bubble.dart';
import '../../ui/button.dart';
import '../../ui/dock.dart';
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
import 'feed_slivers.dart';

/// B1 · Discover · Home (31:24) with the B12 For you behaviour (192:8644):
/// open polls, activations, Closing soon, the interest groups, then More
/// briefs, loaded a page at a time, under the lens chips pinned as chrome.
/// Pull to refresh shows Exp/PullIndicator above the chips; the first load
/// shows skeletons; a failed load shows the error banner; an empty feed
/// shows the trophy.
///
/// Motion (spec 6.20, 5.15 to 5.17, 3.7): the first load waits behind
/// SkeletonGate and its items arrive 40 ms apart (the setup nudge first);
/// one PullIndicator fades in with the pull, turns its arrow when armed
/// (select haptic, once a pull), holds its 52 pt slot while refreshing,
/// shows Done for 800 ms and then closes the slot as the feed slides up; a
/// new page arrives from its first ticket; the lens chips and filters fade
/// the content in (200 ms, no stagger); Try again sends the banner up and
/// waits again, and a failed retry brings it back with the error haptic.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  static const double _loadMoreWithin = 240;

  final _scroll = ScrollController();
  final _arrivals = ArrivalsController();
  final _pull = ValueNotifier<double>(0);
  final _armed = ValueNotifier<bool>(false);
  late final AnimationController _lens = AnimationController(
    vsync: this,
    duration: IqDurations.swap,
    value: 1,
  );
  late final Animation<double> _lensIn = _lens.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  late final AnimationController _slot = AnimationController(vsync: this);
  bool _steady = false;
  bool _buzzed = false;
  bool _retrying = false;
  bool? _nudge;
  IqPullIndicatorState? _closingAs;
  Timer? _doneTimer;

  @override
  void dispose() {
    _doneTimer?.cancel();
    _scroll.dispose();
    _pull.dispose();
    _armed.dispose();
    _lens.dispose();
    _slot.dispose();
    super.dispose();
  }

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  bool get _slotOpen => _slot.value > 0 || _slot.isAnimating;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final metrics = n.metrics;
    if (n is ScrollUpdateNotification) {
      final over = math.max(0.0, metrics.minScrollExtent - metrics.pixels);
      _pull.value = over;
      if (over == 0) _buzzed = false;
      if (n.dragDetails != null) {
        final idle =
            !_slotOpen &&
            ref.read(discoverFeedProvider).value?.refresh == RefreshPhase.idle;
        final armed = idle && over >= IqTravel.pullArm;
        if (armed && !_buzzed) {
          _buzzed = true;
          IqHaptics.select.play();
        }
        _armed.value = armed;
      } else if (_armed.value) {
        _armed.value = false;
        _startRefresh(fromPull: true);
      }
    } else if (n is ScrollEndNotification && _armed.value) {
      _armed.value = false;
      _startRefresh(fromPull: true);
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

  void _startRefresh({required bool fromPull}) {
    final data = ref.read(discoverFeedProvider).value;
    if (data == null || data.refresh != RefreshPhase.idle || _slotOpen) return;
    _openSlot(steady: fromPull);
    ref.read(discoverFeedProvider.notifier).refresh();
  }

  /// A pull hands its overscroll to the slot, so nothing moves and the list
  /// settles onto the slot; a refresh started elsewhere slides it open.
  void _openSlot({required bool steady}) {
    _closingAs = null;
    if (steady) {
      _hold(1);
    } else if (_reduced) {
      setState(() => _slot.value = 1);
    } else {
      _slot.animateTo(1, duration: IqDurations.swap, curve: IqCurves.easeOut);
    }
  }

  /// The slot closes as the feed slides up with it; scrolled away, it goes
  /// at once without moving what is on screen.
  void _closeSlot(IqPullIndicatorState from) {
    if (!_slotOpen) return;
    final hidden =
        _scroll.hasClients && _scroll.position.pixels >= IqTravel.refreshSlot;
    if (hidden || _reduced) {
      if (_reduced && !hidden) {
        setState(() => _slot.value = 0);
      } else {
        _hold(0);
      }
      return;
    }
    setState(() => _closingAs = from);
    _slot
        .animateBack(0, duration: IqDurations.swap, curve: IqCurves.easeIn)
        .whenCompleteOrCancel(() {
          if (mounted) setState(() => _closingAs = null);
        });
  }

  /// Sets the slot without moving what is on screen.
  void _hold(double value) {
    setState(() {
      _steady = true;
      _slot.value = value;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _steady = false);
    });
  }

  void _fadeContent() {
    if (_reduced) {
      _lens.value = 1;
    } else {
      _lens.forward(from: 0);
    }
  }

  void _retry() {
    _retrying = true;
    ref.read(discoverFeedProvider.notifier).retry();
  }

  FeedView _view(FeedData data) => buildFeed(
    briefs: data.briefs,
    filters: ref.read(discoverFiltersProvider),
    interests: ref.read(feedInterestsProvider),
    now: ref.read(clockProvider)(),
    window: data.window,
  );

  void _listen() {
    ref.listen(discoverFiltersProvider, (previous, next) {
      ref.read(discoverFeedProvider.notifier).resetWindow();
      _fadeContent();
    });
    ref.listen(lensSwitchProvider, (previous, next) => _fadeContent());
    ref.listen(discoverFeedProvider.select((f) => f.value?.refresh), (
      previous,
      next,
    ) {
      switch (next) {
        case RefreshPhase.refreshing:
          if (!_slotOpen) _openSlot(steady: false);
        case RefreshPhase.done:
          _arrivals.play();
          _doneTimer?.cancel();
          _doneTimer = Timer(
            IqPullIndicator.doneHold,
            () => ref.read(discoverFeedProvider.notifier).settleRefresh(),
          );
        case RefreshPhase.idle || null:
          _closeSlot(
            previous == RefreshPhase.done
                ? IqPullIndicatorState.done
                : IqPullIndicatorState.refreshing,
          );
      }
    });
    ref.listen(
      discoverFeedProvider.select((f) => f.value?.loadingMore ?? false),
      (previous, next) {
        if (previous == true && !next) _arrivals.play();
      },
    );
    ref.listen(discoverFeedProvider, (previous, next) {
      if (!_retrying || next.isLoading) return;
      _retrying = false;
      if (next.hasError) IqHaptics.error.play();
    });
    scrollToTopOnRetap(ref, context, IqDockActive.discover, _scroll);
  }

  @override
  Widget build(BuildContext context) {
    _listen();
    final feed = ref.watch(discoverFeedProvider);
    final filters = ref.watch(discoverFiltersProvider);
    ref.watch(feedInterestsProvider);
    final data = feed.value;
    final failed = feed.hasError && !feed.isLoading;
    final onboardingDone = ref.watch(
      sessionProvider.select((s) => s.onboardingDone),
    );
    final nudge = _nudge ??= !onboardingDone;
    final payout = ref.watch(recentPayoutProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: IqColors.bg,
      body: SafeArea(
        bottom: false,
        child: CenteredContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DiscoverTopBar(),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: Arrivals(
                    controller: _arrivals,
                    child: CustomScrollView(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        _refreshSlot(data),
                        PinnedFeedChips(
                          selected: filters.forYou
                              ? FeedChip.forYou
                              : FeedChip.all,
                        ),
                        SliverToBoxAdapter(
                          key: const ValueKey('banner'),
                          child: _inset(
                            IqBanner(
                              kind: IqBannerKind.error,
                              title: 'Couldn’t load. Check your connection.',
                              action: 'Try again',
                              visible: failed,
                              margin: const EdgeInsets.only(bottom: IqSpace.s3),
                              onAction: _retry,
                            ),
                          ),
                        ),
                        if (payout != null)
                          SliverToBoxAdapter(
                            key: const ValueKey('payout'),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                IqSpace.s4,
                                0,
                                IqSpace.s4,
                                IqSpace.s3,
                              ),
                              child: PayoutArrivalRow(payout: payout),
                            ),
                          ),
                        SkeletonGate.builder(
                          key: const ValueKey('gate'),
                          loading: data == null && !failed,
                          onOpen: (after) => _arrivals.play(after: after),
                          builder: (context, phase, skeletonOpacity) =>
                              _body(phase, skeletonOpacity, data, nudge),
                        ),
                        SliverToBoxAdapter(
                          key: const ValueKey('inset'),
                          child: SizedBox(
                            height: AppShell.contentInset(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _refreshSlot(FeedData? data) {
    final phase = data?.refresh ?? RefreshPhase.idle;
    final time = data?.refreshedAt == null
        ? ''
        : DateFormat('H:mm').format(data!.refreshedAt!);
    final state = switch (phase) {
      RefreshPhase.refreshing => IqPullIndicatorState.refreshing,
      RefreshPhase.done => IqPullIndicatorState.done,
      RefreshPhase.idle => _closingAs ?? IqPullIndicatorState.pull,
    };
    return AnimatedBuilder(
      animation: _slot,
      builder: (context, child) => RefreshSlot(
        extent: IqTravel.refreshSlot * _slot.value,
        steady: _steady,
        child: child!,
      ),
      child: OverflowBox(
        alignment: Alignment.bottomCenter,
        minHeight: IqTravel.refreshSlot,
        maxHeight: IqTravel.refreshSlot,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            IqSpace.s4,
            0,
            IqSpace.s4,
            IqSpace.s3,
          ),
          child: ValueListenableBuilder<double>(
            valueListenable: _pull,
            builder: (context, pull, _) => ValueListenableBuilder<bool>(
              valueListenable: _armed,
              builder: (context, armed, _) => IqPullIndicator(
                state: state,
                pullExtent: pull,
                armed: armed,
                doneLabel: 'Up to date · $time',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    GatePhase phase,
    Animation<double> skeletonOpacity,
    FeedData? data,
    bool nudge,
  ) {
    final content = phase == GatePhase.handover || phase == GatePhase.content;
    final slivers = <Widget>[
      if (phase == GatePhase.skeleton)
        SliverList.list(key: const ValueKey('skeleton'), children: _loading()),
      if (phase == GatePhase.handover)
        SliverOverlay(
          key: const ValueKey('skeleton-out'),
          child: FadeTransition(
            opacity: skeletonOpacity,
            child: Column(children: _loading()),
          ),
        ),
      if (content && nudge)
        const SliverToBoxAdapter(
          key: ValueKey('nudge'),
          child: ArriveItem(child: _SetupNudgeSlot()),
        ),
      if (content)
        SliverFadeTransition(
          key: const ValueKey('feed'),
          opacity: _lensIn,
          sliver: SliverList.list(
            children: _spaced(data == null ? _failed() : _feed(data)),
          ),
        ),
    ];
    if (slivers.isEmpty) return const SliverToBoxAdapter();
    return SliverMainAxisGroup(slivers: slivers);
  }

  List<Widget> _loading() => gapped([
    for (final kind in const [
      IqSkeletonKind.ticket,
      IqSkeletonKind.ticket,
      IqSkeletonKind.row,
      IqSkeletonKind.ticket,
    ])
      _inset(IqSkeleton(kind: kind)),
  ]);

  /// Each item arrives on its own; the first sits right under the chips,
  /// the rest 12 apart.
  List<Widget> _spaced(List<_Item> items) => [
    for (final (i, item) in items.indexed)
      ArriveItem(
        key: ValueKey(item.key),
        child: Padding(
          padding: EdgeInsets.only(top: i == 0 || item.ownGap ? 0 : IqSpace.s3),
          child: item.child,
        ),
      ),
  ];

  List<_Item> _failed() => [
    ..._proposals(),
    _Item(
      'failed',
      _inset(
        const _EmptyText(
          title: 'Nothing to show yet',
          body: 'They will show here once they load.',
        ),
      ),
    ),
  ];

  /// Open polls and the Activations row, each behind its flag.
  List<_Item> _proposals() {
    final brands = Flags.polls
        ? ref.watch(pollBrandsProvider).value ?? const []
        : const [];
    final activations = Flags.activations
        ? ref.watch(activationsSummaryProvider).value
        : null;
    return [
      if (brands.isNotEmpty) ...[
        _Item(
          'polls-title',
          _inset(
            IqSectionTitle(
              title: 'Open polls',
              count: '${brands.length}',
              onSeeAll: () => context.push(Routes.polls),
            ),
          ),
        ),
        _Item(
          'polls',
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: gappedRow([
                for (final (i, brand) in brands.indexed)
                  _Pop(
                    index: i,
                    child: IqBrandBubble(
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
                  ),
              ]),
            ),
          ),
        ),
      ],
      if (activations != null)
        _Item(
          'activations',
          _inset(
            IqListRow(
              label: 'Activations',
              description: activations.closingToday == 1
                  ? '1 closes today'
                  : '${activations.closingToday} close today',
              showDescription: activations.closingToday > 0,
              icon: IqIcons.timer,
              divider: false,
              onTap: () => context.push(Routes.activations),
            ),
          ),
        ),
    ];
  }

  List<_Item> _feed(FeedData data) {
    final view = _view(data);
    final filters = ref.read(discoverFiltersProvider);
    if (view.isEmpty && filters.narrowed) {
      return [
        ..._proposals(),
        _Item(
          'empty',
          _inset(
            const _EmptyText(
              illustration: IqIllustrations.trophy,
              title: 'No briefs match these filters',
            ),
          ),
        ),
        _Item(
          'clear',
          _inset(
            IqButton(
              label: 'Clear filters',
              kind: IqButtonKind.ghost,
              showIcon: false,
              width: double.infinity,
              onTap: () => ref
                  .read(discoverFiltersProvider.notifier)
                  .apply(const DiscoverFilters()),
            ),
          ),
        ),
      ];
    }
    if (view.isEmpty) {
      return [
        ..._proposals(),
        _Item(
          'empty',
          _inset(
            const _EmptyText(
              illustration: IqIllustrations.trophy,
              title: 'No open briefs right now',
              body: 'New briefs land here.',
            ),
          ),
        ),
      ];
    }
    void openFilters() => context.go(Routes.filters);
    final status = filters.status.label.toLowerCase();
    return [
      ..._proposals(),
      if (view.closingSoon.isNotEmpty) ...[
        _Item(
          'closing-title',
          _inset(
            IqSectionTitle(
              title: 'Closing soon',
              count: '${view.closingSoon.length}',
              onSeeAll: openFilters,
            ),
          ),
        ),
        _Item(
          'closing',
          SizedBox(
            height: 188,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
              itemCount: view.closingSoon.length,
              separatorBuilder: (context, i) =>
                  const SizedBox(width: IqSpace.s3),
              itemBuilder: (context, i) => BriefTicket(
                brief: view.closingSoon[i],
                kind: IqTicketCardKind.hero,
              ),
            ),
          ),
        ),
      ],
      for (final (i, group) in view.groups.indexed) ...[
        _Item(
          'group:${group.title}',
          _inset(
            IqSectionTitle(
              title: group.title,
              count: '${group.total}',
              showLink: i == 0,
              link: 'Filter',
              onSeeAll: () => context.go(Routes.yourDetails),
            ),
          ),
        ),
        for (final brief in group.briefs)
          _Item(
            'group:${group.title}:${brief.id}',
            Center(child: BriefTicket(brief: brief)),
          ),
      ],
      if (view.more.total > 0) ...[
        _Item(
          'more',
          _inset(
            IqSectionTitle(
              title: view.more.title,
              count: '${view.more.total}',
              link: 'Filter',
              onSeeAll: openFilters,
            ),
          ),
        ),
        for (final brief in view.more.briefs)
          _Item('more:${brief.id}', Center(child: BriefTicket(brief: brief))),
      ],
      _Item(
        'tail',
        _Tail(
          loading: data.loadingMore,
          end: data.loadingMore || view.hasMore
              ? null
              : view.total == 1
              ? 'That’s the only $status brief'
              : 'That’s all ${view.total} $status briefs',
          onAdjust: () => context.go(Routes.yourDetails),
        ),
        ownGap: true,
      ),
    ];
  }
}

class _Item {
  const _Item(this.key, this.child, {this.ownGap = false});

  final String key;
  final Widget child;

  /// The item opens its own gap above it (it may have nothing to show).
  final bool ownGap;
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

/// The setup nudge with the gap under it, so both fold away together.
class _SetupNudgeSlot extends StatelessWidget {
  const _SetupNudgeSlot();

  @override
  Widget build(BuildContext context) =>
      _inset(const SetupNudge(gap: IqSpace.s3));
}

/// A brand bubble popping in 40 ms after the one before, inside its row's
/// arrival (spec 6.20).
class _Pop extends StatelessWidget {
  const _Pop({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final beat = ArriveItem.beatOf(
      context,
      lead: IqDurations.stagger * index,
      length: IqDurations.appear,
    );
    if (beat == null) return child;
    return FadeTransition(
      opacity: beat,
      child: ScaleTransition(
        scale: beat.drive(Tween(begin: IqScale.pop, end: 1)),
        child: child,
      ),
    );
  }
}

/// The end of the list: the next page's skeleton with "LOADING MORE"
/// appearing while it loads (220 ms), fading as the page lands (150 ms);
/// then, once every brief is in, the end line and "Adjust interests"
/// appear 40 ms apart (spec 5.17).
class _Tail extends StatelessWidget {
  const _Tail({required this.loading, required this.end, this.onAdjust});

  final bool loading;
  final String? end;
  final VoidCallback? onAdjust;

  @override
  Widget build(BuildContext context) {
    final end = this.end;
    final Widget child;
    if (loading) {
      child = Padding(
        key: const ValueKey('loading'),
        padding: const EdgeInsets.only(top: IqSpace.s3),
        child: Appear(
          child: Column(
            children: [
              _inset(const IqSkeleton()),
              const SizedBox(height: IqSpace.s3),
              _inset(
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Loading more'.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: IqText.mono.copyWith(color: IqColors.fg3),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (end != null) {
      child = Padding(
        key: const ValueKey('end'),
        padding: const EdgeInsets.only(top: IqSpace.s3),
        child: Column(
          children: [
            Appear(
              child: _inset(
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    end,
                    textAlign: TextAlign.center,
                    style: IqText.body.copyWith(color: IqColors.fg2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: IqSpace.s3),
            Appear(
              delay: IqDurations.stagger,
              child: _inset(
                IqButton(
                  label: 'Adjust interests',
                  kind: IqButtonKind.ghost,
                  showIcon: false,
                  width: double.infinity,
                  onTap: onAdjust,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      child = const SizedBox(key: ValueKey('none'), width: double.infinity);
    }
    return AnimatedSwitcher(
      duration: motion(context, IqDurations.appear),
      reverseDuration: motion(context, IqDurations.crossfade),
      switchInCurve: IqCurves.easeOut,
      switchOutCurve: IqCurves.easeOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      // The new tail plays its own entrance; only the old one fades here.
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => Opacity(
          opacity: animation.status == AnimationStatus.reverse
              ? animation.value
              : 1,
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// The empty and failed feed: an optional illustration, then a card title
/// and one line appearing at +80 and +120 (spec 6.24).
class _EmptyText extends StatelessWidget {
  const _EmptyText({required this.title, this.body, this.illustration});

  final String title;
  final String? body;
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
          Appear(
            delay: IqDurations.stagger * 2,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: IqText.cardTitle.copyWith(color: IqColors.fg),
              ),
            ),
          ),
          if (body case final body?) ...[
            const SizedBox(height: IqSpace.s2),
            Appear(
              delay: IqDurations.stagger * 3,
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  body,
                  textAlign: TextAlign.center,
                  style: IqText.body.copyWith(color: IqColors.fg2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
