import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/deadline.dart';
import '../../core/edge_haptics.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/session.dart';
import '../../core/transitions.dart';
import '../../core/updates.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../core/money.dart';
import '../../data/activations_data.dart';
import '../../data/device.dart';
import '../../data/repository.dart';
import '../../data/polls_data.dart';
import '../../ui/banner.dart';
import '../../ui/brief_card.dart';
import '../../ui/button.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/dock.dart';
import '../../ui/empty_state.dart';
import '../../ui/illustration.dart';
import '../../ui/meta.dart';
import '../../ui/pull_indicator.dart';
import '../../ui/section_title.dart';
import '../../ui/skeleton.dart';
import '../activations/activation_format.dart' hide activationCover;
import '../activations/activations_routes.dart';
import '../activations/activations_state.dart';
import '../entry/first_tip.dart';
import '../entry/notifications_ask_screen.dart';
import '../polls/polls_routes.dart';
import '../polls/polls_state.dart';
import '../polls/quick_poll_tile.dart';
import '../onboarding/setup_nudge.dart';
import '../withdrawals/payout_arrival.dart';
import 'app_shell.dart';
import 'business_art.dart';
import 'discover_state.dart';
import 'discover_widgets.dart';
import 'feed_slivers.dart';

/// B1 · Discover · Home (31:24, For you; 480:20532, All): Quick polls,
/// Activations, then Briefs (and on For you More briefs), loaded a page at
/// a time under the lens chips pinned as chrome. Pull to refresh shows
/// Exp/PullIndicator above the chips (192:8909); the first visit shows
/// skeleton cards (165:8171, 192:9042); a failed load shows the error
/// banner and the Thinker (165:8401); an empty feed the Shrug (165:8285).
///
/// Motion: the first load waits behind LoadingGate and its items arrive
/// 40 ms apart; later dock returns show the feed as it was and refresh it
/// quietly; the lens chips and filters cross the content under the still
/// chips (200 ms); the gift's shine plays once a session, 0.8 s after the
/// first load lands, never on a refresh.
///
/// A newer build is offered here only (B · Update · available, 1311:26531),
/// after the feed has landed and the first tip has had its turn: at once for
/// a new version, then once a day until it is installed.
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
  final _chips = GlobalKey();
  final _pull = ValueNotifier<double>(0);
  final _armed = ValueNotifier<bool>(false);
  late final AnimationController _slot = AnimationController(vsync: this);
  bool _steady = false;
  bool _buzzed = false;
  bool _retrying = false;
  bool _built = false;
  bool _landed = false;
  bool? _nudge;
  IqPullIndicatorState? _closingAs;
  Timer? _doneTimer;
  Timer? _shineTimer;
  Timer? _offerTimer;
  bool _shine = false;
  bool _proposalsPending = false;

  /// Whether the skeleton drew the proposals above its cards (165:8171):
  /// set when it first shows, so nothing above the cards is inserted later,
  /// and what it drew stands still through the hand-over.
  bool? _standing;

  @override
  void dispose() {
    _doneTimer?.cancel();
    _shineTimer?.cancel();
    _offerTimer?.cancel();
    _scroll.dispose();
    _pull.dispose();
    _armed.dispose();
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
          if (!(PullsToRefresh.of(context)?.reachedTop ?? false)) {
            IqHaptics.select.play();
          }
        }
        _armed.value = armed;
      } else {
        _release();
      }
    } else if (n is ScrollEndNotification) {
      _release();
    }
    if (metrics.extentAfter < _loadMoreWithin) _maybeLoadMore();
    return false;
  }

  /// The finger lifted: a pull past 64 refreshes.
  void _release() {
    if (!_armed.value) return;
    _armed.value = false;
    _startRefresh(fromPull: true);
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

  /// A pull hands its overscroll to the slot, so nothing jumps, and the list
  /// settles onto the slot over 200 ms ease-out; a refresh started elsewhere
  /// slides it open.
  void _openSlot({required bool steady}) {
    _closingAs = null;
    if (steady) {
      _hold(1, then: _settleOnSlot);
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
  void _hold(double value, {VoidCallback? then}) {
    setState(() {
      _steady = true;
      _slot.value = value;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _steady = false);
      then?.call();
    });
  }

  void _settleOnSlot() {
    if (!_scroll.hasClients) return;
    final top = _scroll.position.minScrollExtent;
    if (_scroll.position.pixels >= top) return;
    if (_reduced) {
      _scroll.jumpTo(top);
    } else {
      _scroll.animateTo(
        top,
        duration: IqDurations.swap,
        curve: IqCurves.easeOut,
      );
    }
  }

  void _crossContent() {
    final chips = _chips.currentContext;
    if (chips != null) LensCrossfade.cross(context, line: chips);
  }

  void _retry() {
    _retrying = true;
    ref.read(discoverFeedProvider.notifier).retry();
  }

  /// The feed is on screen, arriving [after] from now: the first tip may
  /// follow (spec 3.8). Told after the frame, as it lands mid-build.
  void _land(Duration after) {
    if (_landed) return;
    _landed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(firstTipCueProvider.notifier).cue(after);
      _offerTimer = Timer(after + IqDurations.tipWait, _offerUpdate);
      if (ref.read(giftShineSpentProvider)) return;
      ref.read(giftShineSpentProvider.notifier).spend();
      _shineTimer = Timer(after + IqDurations.giftShineDelay, () {
        if (mounted) setState(() => _shine = true);
      });
    });
  }

  void _offerUpdate() {
    if (!mounted || !_landed || !TickerMode.valuesOf(context).enabled) return;
    if (!ref.read(sessionProvider).firstTipSeen) return;
    unawaited(_offerAfterNotifications());
  }

  /// The notifications ask comes once, in place of the update offer, when
  /// the phone does not let iQLY notify and this person never saw it.
  Future<void> _offerAfterNotifications() async {
    if (!ref.read(notificationsAskedProvider)) {
      final asked = ref.read(notificationsAskedProvider.notifier);
      if (!await ref.read(deviceServiceProvider).notificationsAllowed()) {
        if (!mounted) return;
        whenUncovered(context, () {
          if (mounted) unawaited(context.open(Routes.notificationsAsk));
        });
        return;
      }
      await asked.mark();
      if (!mounted) return;
    }
    final updates = ref.read(updatesProvider.notifier);
    if (!updates.offer) return;
    whenUncovered(context, () async {
      if (!mounted || !updates.offer) return;
      final url = ref.read(updatesProvider)?.updateUrl;
      final navigator = Navigator.of(context, rootNavigator: true);
      await updates.offered();
      if (!navigator.mounted) return;
      final update = await showIqConfirmSheet(
        navigator.context,
        title: 'A new version is available',
        body: 'Update iQLY to get the latest fixes and features.',
        confirmLabel: 'Update iQLY',
        cancelLabel: 'Not now',
        confirmKind: IqButtonKind.primary,
        scrim: IqScrim.fg,
      );
      if (!update || url == null || !mounted) return;
      await ref.read(deviceServiceProvider).openUrl(url);
    });
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
      _crossContent();
      ref.read(discoverFeedProvider.notifier).resetWindow();
    });
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
    ref.listen(tabEntryProvider, (previous, next) {
      if (next?.tab != IqDockActive.discover) return;
      ref.read(discoverFeedProvider.notifier).refreshQuietly();
      if (ref.read(pollsShownProvider)) {
        ref.read(pollsProvider.notifier).refreshQuietly();
      }
      // The tab is told before the dock switch shows it.
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerUpdate());
    });
    ref.listen(updatesProvider, (previous, next) => _offerUpdate());
  }

  @override
  Widget build(BuildContext context) {
    _listen();
    final feed = ref.watch(discoverFeedProvider);
    final filters = ref.watch(discoverFiltersProvider);
    ref.watch(feedInterestsProvider);
    final data = feed.value;
    final failed = feed.hasError && !feed.isLoading;
    final proposalsPending =
        (ref.watch(pollsShownProvider) && _pending(ref.watch(pollsProvider))) ||
        (ref.watch(activationsShownProvider) &&
            _pending(ref.watch(activationsProvider)));
    final onboardingDone = ref.watch(
      sessionProvider.select((s) => s.onboardingDone),
    );
    final nudge = _nudge ??= !onboardingDone;
    final payout = ref.watch(recentPayoutProvider);
    _proposalsPending = proposalsPending;
    final loading = (data == null && !failed) || proposalsPending;
    if (!_built) {
      _built = true;
      if (!loading) _land(Duration.zero);
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: IqColors.bg,
      body: SafeArea(
        bottom: false,
        child: CenteredContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DiscoverTopBar(giftShine: _shine),
              Expanded(
                child: Listener(
                  onPointerUp: (_) => _release(),
                  onPointerCancel: (_) => _release(),
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
                            chipsKey: _chips,
                            // While the Saved lens, its own route, covers
                            // this page, these chips show Saved too, so a
                            // pick there lands here from Saved rather than
                            // from the lens this page held before.
                            selected: ModalRoute.isCurrentOf(context) == false
                                ? FeedChip.saved
                                : filters.forYou
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
                                margin: const EdgeInsets.only(
                                  bottom: IqSpace.s3,
                                ),
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
                          LoadingGate.builder(
                            key: const ValueKey('gate'),
                            loading: loading,
                            onOpen: (after) {
                              _arrivals.play(after: after);
                              _land(after);
                            },
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
    if (phase == GatePhase.waiting) _standing = null;
    if (phase == GatePhase.skeleton) {
      _standing ??= !_proposalsPending && _proposals().isNotEmpty;
    }
    final standing = _standing ?? false;
    final content = phase == GatePhase.handover || phase == GatePhase.content;
    final slivers = <Widget>[
      if (phase == GatePhase.skeleton)
        SliverList.list(
          key: const ValueKey('skeleton'),
          children: _loading(nudge: nudge),
        ),
      if (phase == GatePhase.handover)
        SliverOverlay(
          key: const ValueKey('skeleton-out'),
          child: FadeTransition(
            opacity: skeletonOpacity,
            child: Column(children: _loading(nudge: nudge, handover: true)),
          ),
        ),
      if (content && nudge)
        SliverToBoxAdapter(
          key: const ValueKey('nudge'),
          child: standing
              ? const _SetupNudgeSlot()
              : const ArriveItem(child: _SetupNudgeSlot()),
        ),
      if (content)
        if (data == null ? _failed() : _emptyFeed(data) case final empty?)
          IqSliverEmptyFill(
            key: const ValueKey('feed'),
            bottom: AppShell.contentInset(context),
            child: empty,
          )
        else
          SliverList.list(
            key: const ValueKey('feed'),
            children: _spaced(_feed(data!), standing: standing),
          ),
    ];
    if (slivers.isEmpty) return const SliverToBoxAdapter();
    return SliverMainAxisGroup(slivers: slivers);
  }

  /// The first load: the two skeleton cards alone (B12 192:9042), or under
  /// the setup nudge, Quick polls, Activations and the Briefs heading when
  /// those were all in as the skeleton showed (B1 165:8171). In the
  /// hand-over only the cards fade: the rest is the feed's own, standing
  /// in place, so this keeps its space and draws nothing.
  List<Widget> _loading({required bool nudge, bool handover = false}) {
    final cards = gapped([
      _inset(const _SkeletonCard()),
      _inset(const _SkeletonCard()),
    ]);
    if (!(_standing ?? false)) return cards;
    final proposals = _proposals();
    final lead = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (nudge) const _SetupNudgeSlot(),
        for (final (i, item) in proposals.indexed) ...[
          if (i > 0) SizedBox(height: item.gap),
          item.child,
        ],
        _sectionGap,
        _briefsTitle(),
        const SizedBox(height: IqSpace.s3),
      ],
    );
    return [
      if (handover)
        IgnorePointer(
          child: ExcludeSemantics(child: Opacity(opacity: 0, child: lead)),
        )
      else
        lead,
      ...cards,
    ];
  }

  /// Each item arrives on its own, the first right under the chips, the
  /// rest 12 apart; with [standing], what the skeleton drew (everything down
  /// to the Briefs heading) stands in place.
  List<Widget> _spaced(List<_Item> items, {bool standing = false}) {
    final drawn = standing
        ? items.indexWhere((item) => item.key == 'briefs-title')
        : -1;
    return [
      for (final (i, item) in items.indexed)
        if (i <= drawn)
          KeyedSubtree(
            key: ValueKey(item.key),
            child: Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : item.gap),
              child: item.child,
            ),
          )
        else
          ArriveItem(
            key: ValueKey(item.key),
            child: Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : item.gap),
              child: item.child,
            ),
          ),
    ];
  }

  Widget _failed() => const IqEmptyState(
    figure: IqFigures.thinker,
    title: 'Couldn’t load briefs',
    body: 'Check your data or Wi-Fi and try again.',
  );

  /// Quick polls and Activations sit above the feed, so the feed waits for
  /// their first answer rather than being pushed down when they land.
  static bool _pending(AsyncValue<Object?> value) =>
      !value.hasValue && !value.hasError;

  static const double _section = IqSpace.s6 + IqSpace.s3;
  static const Widget _sectionGap = SizedBox(height: _section);

  Widget _briefsTitle() => _inset(
    IqSectionTitle(
      title: 'Briefs',
      showCount: false,
      link: 'Filter',
      onSeeAll: () => context.go(Routes.filters),
    ),
  );

  /// Quick polls and the Activations block, each behind its flag and only
  /// in a preview launch.
  List<_Item> _proposals() {
    final businesses = ref.watch(pollsShownProvider)
        ? ref.watch(pollsProvider).value ?? const <PollBusiness>[]
        : const <PollBusiness>[];
    final activations = ref.watch(activationsShownProvider)
        ? ref.watch(activationsProvider).value ?? const <Activation>[]
        : const <Activation>[];
    final now = ref.watch(clockProvider)();
    final open = [
      for (final a in activations)
        if (!a.closedAt(now) && !a.credited) a,
    ]..sort((a, b) => a.closesAt.compareTo(b.closesAt));
    void openActivations() => context.open(
      open.length == 1 ? activationPath(open.single.id) : Routes.activations,
    );
    return [
      if (businesses.isNotEmpty) ...[
        _Item(
          'polls-title',
          _inset(
            IqSectionTitle(
              title: 'Quick polls',
              showCount: false,
              onSeeAll: () => context.open(Routes.polls),
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
                for (final business in businesses)
                  QuickPollTile(
                    business: business,
                    onTap: () => context.open(quickPollsFor(business.id)),
                  ),
              ]),
            ),
          ),
        ),
      ],
      if (open.isNotEmpty) ...[
        _Item(
          'activations-title',
          _inset(
            IqSectionTitle(
              title: 'Activations',
              showCount: false,
              onSeeAll: openActivations,
            ),
          ),
          gap: businesses.isEmpty ? 0 : _section,
        ),
        _Item(
          'activations',
          _inset(
            IqBriefCard(
              kind: IqBriefCardKind.row,
              brand: open.first.business,
              title: open.first.title,
              cover: businessCover(activationCover(open.first)),
              logo: businessLogo(activationLogo(open.first)),
              meta: [
                IqMeta(
                  kind: IqMetaKind.reward,
                  label: rewardShort(open.first.rewardKobo),
                ),
                IqMeta(
                  kind: IqMetaKind.urgent,
                  label:
                      'Closes in ${countdownText(activationLeft(open.first, now))}',
                ),
              ],
              onTap: openActivations,
            ),
          ),
        ),
      ],
    ];
  }

  /// The empty feed, or null when it has briefs. Its button only leads
  /// somewhere else: For you points to All, and filters can be cleared.
  Widget? _emptyFeed(FeedData data) {
    if (!_view(data).isEmpty) return null;
    final filters = ref.read(discoverFiltersProvider);
    final narrowed = filters.narrowed;
    return IqEmptyState(
      figure: narrowed ? IqFigures.shrug : IqFigures.writer,
      title: narrowed
          ? 'No briefs match these filters'
          : 'No open briefs right now',
      body: narrowed ? null : 'New briefs land here.',
      action: narrowed ? 'Clear filters' : 'See all briefs',
      onAction: narrowed
          ? () => ref
                .read(discoverFiltersProvider.notifier)
                .apply(const DiscoverFilters())
          : filters.forYou
          ? () {
              _crossContent();
              ref.read(discoverFiltersProvider.notifier).showAll();
            }
          : null,
    );
  }

  List<_Item> _feed(FeedData data) {
    final view = _view(data);
    final filters = ref.read(discoverFiltersProvider);
    final proposals = _proposals();
    final lead = proposals.isEmpty ? 0.0 : _section;
    final status = filters.status.label.toLowerCase();
    return [
      ...proposals,
      _Item('briefs-title', _briefsTitle(), gap: lead),
      for (final brief in view.briefs.briefs)
        _Item('briefs:${brief.id}', _inset(BriefFeatureCard(brief: brief))),
      if (view.more.briefs.isNotEmpty) ...[
        _Item(
          'more',
          _inset(
            IqSectionTitle(
              title: view.more.title,
              showCount: false,
              link: 'Filter',
              onSeeAll: () => context.go(Routes.filters),
            ),
          ),
          gap: _section,
        ),
        for (final brief in view.more.briefs)
          _Item('more:${brief.id}', _inset(BriefFeatureCard(brief: brief))),
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
          onAdjust: () => context.open(Routes.yourDetails),
        ),
        gap: 0,
      ),
    ];
  }
}

class _Item {
  const _Item(this.key, this.child, {this.gap = IqSpace.s3});

  final String key;
  final Widget child;

  /// The space above it; the tail opens its own (it may show nothing).
  final double gap;
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
                    'Loading more…',
                    textAlign: TextAlign.center,
                    style: IqText.smallStrong.copyWith(color: IqColors.fg3),
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

/// A brief card while the feed loads (165:8171): the photo block and the
/// business, title and chip bars on the card, pulsing on the screen's beat.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    Widget bar(Animation<double> opacity, double w, double h) => FadeTransition(
      opacity: opacity,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: IqColors.panel,
          borderRadius: BorderRadius.circular(h / 2),
        ),
      ),
    );
    return Semantics(
      label: 'Loading',
      child: SkeletonPulse(
        builder: (context, opacity) => Container(
          height: 298,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: IqColors.card,
            borderRadius: BorderRadius.circular(IqRadius.xl2),
            border: Border.all(color: IqColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeTransition(
                opacity: opacity,
                child: Container(height: 168, color: IqColors.panel),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  IqSpace.s4,
                  IqSpace.s3,
                  IqSpace.s4,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(opacity, 120, 12),
                    const SizedBox(height: IqSpace.s2p5),
                    bar(opacity, 280, 16),
                    const SizedBox(height: IqSpace.s2p5),
                    bar(opacity, 200, 16),
                    const SizedBox(height: IqSpace.s2p5),
                    Row(
                      children: [
                        bar(opacity, 96, 26),
                        const SizedBox(width: IqSpace.s2),
                        bar(opacity, 64, 26),
                        const SizedBox(width: IqSpace.s2),
                        bar(opacity, 80, 26),
                      ],
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
}
