import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/money.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/biz_filter_chip.dart';
import '../../ui/biz_segment.dart';
import '../../ui/bookmark.dart';
import '../../ui/brief_card.dart';
import '../../ui/button.dart';
import '../../ui/empty_state.dart';
import '../../ui/illustration.dart';
import '../../ui/meta.dart';
import '../../ui/pressable.dart';
import '../../ui/ticket_card.dart';
import '../../ui/web_filter_option.dart';
import '../../ui/web_range_field.dart';
import '../shell/tablet_page.dart';
import '../shell/tablet_popover.dart';
import 'business_art.dart';
import 'discover_state.dart';
import 'discover_widgets.dart';
import 'tablet_discover_state.dart';

/// T4 · Discover (Mobile App · tablet, 1832:39548): For you, All and Saved
/// on one page. The toolbar carries the lens tabs, the count, Filters and
/// Sort; Filters drops the desktop filter set as a popover (two columns in
/// portrait, three in landscape) and an applied filter shows as a chip
/// under the toolbar. For you leads with the briefs closing within two
/// days as tickets, then More briefs; All and Saved are one grid. Portrait
/// lays the grid in two columns, landscape in three.
///
/// Figma over the phone feed: Quick polls and Activations leave Discover,
/// as they have their own rail items, and the cards carry the reward and
/// the deadline only.
class TabletDiscover extends ConsumerStatefulWidget {
  const TabletDiscover({super.key, this.savedRoute = false});

  /// Opened as the Saved route (/home/saved): the Saved lens, and the other
  /// lenses go back to Discover.
  final bool savedRoute;

  @override
  ConsumerState<TabletDiscover> createState() => _TabletDiscoverState();
}

enum _Open { none, filters, sort }

class _TabletDiscoverState extends ConsumerState<TabletDiscover> {
  final _scroll = ScrollController();
  _Open _open = _Open.none;
  TabletFilters? _draft;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toggle(_Open open) => setState(() {
    _open = _open == open ? _Open.none : open;
    _draft = _open == _Open.filters ? ref.read(tabletFiltersProvider) : null;
  });

  void _close() => setState(() {
    _open = _Open.none;
    _draft = null;
  });

  void _clearFilters() =>
      ref.read(tabletFiltersProvider.notifier).apply(const TabletFilters());

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(discoverFeedProvider);
    final now = ref.watch(clockProvider)();
    final saved = widget.savedRoute || ref.watch(tabletSavedLensProvider);
    final sort = ref.watch(discoverFiltersProvider.select((f) => f.sort));
    final forYou = !saved && sort == FeedSort.myInterests;
    final filters = ref.watch(tabletFiltersProvider);
    final savedBriefs = ref.watch(savedBriefsProvider).value ?? const [];
    final briefs = feed.value?.briefs;
    final live = [
      for (final b in briefs ?? const <Brief>[])
        if (b.isLive) b,
    ];
    final source = saved ? savedBriefs : live;
    final matching = [
      for (final b in source)
        if (filters.matches(b, now)) b,
    ];
    final expanded = Layout.isExpanded(context);

    final subtitle = saved
        ? '${savedBriefs.length} saved ${savedBriefs.length == 1 ? 'brief' : 'briefs'}.'
        : forYou
        ? '${live.length} live briefs, your interests first.'
        : '${live.length} live briefs.';

    final toolbar = _toolbar(
      saved: saved,
      forYou: forYou,
      sort: sort,
      count: briefs == null ? null : matching.length,
      filters: filters,
      live: live,
      now: now,
    );
    final chips = filters.chips();

    final children = <Widget>[
      toolbar,
      if (chips.isNotEmpty)
        Wrap(
          spacing: IqSpace.s2,
          runSpacing: IqSpace.s2,
          children: [
            for (final (label, without) in chips)
              IqBizFilterChip(
                label: label,
                state: IqBizFilterChipState.active,
                onClear: () =>
                    ref.read(tabletFiltersProvider.notifier).apply(without),
              ),
          ],
        ),
      if (feed.hasError && briefs == null)
        const IqEmptyState(
          figure: IqFigures.thinker,
          title: 'Couldn’t load briefs',
          body: 'Check your data or Wi-Fi and try again.',
        )
      else if (briefs == null)
        ..._loading(forYou: forYou, expanded: expanded)
      else if (matching.isEmpty)
        _empty(saved: saved, narrowed: filters.narrowed, forYou: forYou)
      else
        ..._results(
          matching,
          now: now,
          forYou: forYou,
          saved: saved,
          savedBriefs: savedBriefs,
          sort: sort,
          expanded: expanded,
          narrowed: filters.narrowed,
          total: saved ? savedBriefs.length : live.length,
        ),
    ];

    return TabletPage(
      controller: _scroll,
      title: 'Discover',
      subtitle: subtitle,
      children: children,
    );
  }

  Widget _toolbar({
    required bool saved,
    required bool forYou,
    required FeedSort sort,
    required int? count,
    required TabletFilters filters,
    required List<Brief> live,
    required DateTime now,
  }) {
    final lens = ref.read(discoverFiltersProvider.notifier);
    final savedLens = ref.read(tabletSavedLensProvider.notifier);
    void leaveSaved() {
      savedLens.set(false);
      if (widget.savedRoute) context.go(Routes.home);
    }

    IqBizSegmentState state(bool on) =>
        on ? IqBizSegmentState.selected : IqBizSegmentState.standard;
    final expanded = Layout.isExpanded(context);
    return Row(
      children: [
        IqBizSegment.track(
          children: [
            IqBizSegment(
              label: 'For you',
              state: state(forYou),
              onTap: () {
                leaveSaved();
                lens.showForYou();
              },
            ),
            IqBizSegment(
              label: 'All',
              state: state(!saved && !forYou),
              onTap: () {
                leaveSaved();
                lens.showAll();
              },
            ),
            if (Flags.savedBriefs)
              IqBizSegment(
                label: 'Saved',
                state: state(saved),
                onTap: () => savedLens.set(true),
              ),
          ],
        ),
        const Spacer(),
        if (count != null) ...[
          Text(
            '$count ${count == 1 ? 'brief' : 'briefs'}',
            style: IqWebText.bodySmall.copyWith(color: IqColors.fg3),
          ),
          const SizedBox(width: IqSpace.s3),
        ],
        TabletPopover(
          open: _open != _Open.none,
          onClose: _close,
          anchor: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IqBizFilterChip(
                label: 'Filters',
                state: _open == _Open.filters || filters.narrowed
                    ? IqBizFilterChipState.active
                    : IqBizFilterChipState.standard,
                onTap: () => _open == _Open.filters || !filters.narrowed
                    ? _toggle(_Open.filters)
                    : _clearFilters(),
              ),
              const SizedBox(width: IqSpace.s3),
              IqBizFilterChip(
                label: 'Sort: ${sort.label}',
                onTap: () => _toggle(_Open.sort),
              ),
            ],
          ),
          popover: _open == _Open.sort
              ? TabletMenu<FeedSort>(
                  options: FeedSort.values,
                  label: (s) => s.label,
                  selected: sort,
                  onPick: (s) {
                    _close();
                    final current = ref.read(discoverFiltersProvider);
                    lens.apply(current.copyWith(sort: s));
                  },
                )
              : _FiltersPopover(
                  draft: _draft ?? filters,
                  live: live,
                  now: now,
                  wide: expanded,
                  onChanged: (draft) => setState(() => _draft = draft),
                  onShow: () {
                    ref
                        .read(tabletFiltersProvider.notifier)
                        .apply(_draft ?? filters);
                    _close();
                  },
                ),
        ),
      ],
    );
  }

  List<Widget> _loading({required bool forYou, required bool expanded}) {
    final columns = expanded ? 3 : 2;
    return [
      if (forYou)
        Wrap(
          spacing: IqSpace.s6,
          runSpacing: IqSpace.s6,
          children: [
            const _Bones(widths: [160, 190, 120]),
            for (var i = 0; i < 2; i++)
              Container(
                width: 300,
                height: 188,
                decoration: BoxDecoration(
                  color: IqColors.panel,
                  borderRadius: BorderRadius.circular(IqRadius.xl2),
                ),
              ),
          ],
        ),
      _Grid(
        columns: columns,
        children: [for (var i = 0; i < columns * 3; i++) const _CardBones()],
      ),
    ];
  }

  Widget _empty({
    required bool saved,
    required bool narrowed,
    required bool forYou,
  }) {
    if (narrowed) {
      return IqEmptyState(
        figure: IqFigures.shrug,
        title: 'No briefs match these filters',
        body: 'Try widening your search or clearing some filters.',
        action: 'Clear filters',
        onAction: _clearFilters,
      );
    }
    if (saved) {
      return IqEmptyState(
        figure: IqFigures.saver,
        title: 'Nothing saved yet',
        body: 'Tap the bookmark on any brief.',
        action: 'Browse briefs',
        onAction: () => ref.read(tabletSavedLensProvider.notifier).set(false),
      );
    }
    return IqEmptyState(
      figure: IqFigures.writer,
      title: 'No open briefs right now',
      body: 'New briefs land here.',
      action: forYou ? 'See all briefs' : null,
      onAction: forYou
          ? () => ref.read(discoverFiltersProvider.notifier).showAll()
          : null,
    );
  }

  List<Widget> _results(
    List<Brief> matching, {
    required DateTime now,
    required bool forYou,
    required bool saved,
    required List<Brief> savedBriefs,
    required FeedSort sort,
    required bool expanded,
    required bool narrowed,
    required int total,
  }) {
    final columns = expanded ? 3 : 2;
    final interests = ref.watch(feedInterestsProvider);
    final view = buildFeed(
      briefs: matching,
      filters: DiscoverFilters(sort: forYou ? FeedSort.myInterests : sort),
      interests: interests,
      now: now,
      window: matching.length,
    );
    final ordered = [...view.briefs.briefs, ...view.more.briefs];
    final closing = forYou
        ? ordered.where((b) => isClosingSoon(b, now)).toList()
        : const <Brief>[];
    final grid = [
      for (final b in ordered)
        if (!closing.contains(b)) b,
    ];
    bool isSaved(Brief b) => savedBriefs.any((s) => s.id == b.id);
    final noun = saved ? 'saved briefs' : 'live briefs';
    return [
      if (closing.isNotEmpty)
        _ClosingSoon(
          briefs: closing,
          allSaved: closing.every(isSaved),
          anySaved: savedBriefs.isNotEmpty,
          expanded: expanded,
          onSeeSaved: () =>
              ref.read(tabletSavedLensProvider.notifier).set(true),
        ),
      if (closing.isNotEmpty && grid.isNotEmpty)
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'More briefs',
              style: IqText.title.copyWith(color: IqColors.fg),
            ),
            const SizedBox(width: IqSpace.s2),
            Text(
              '${grid.length}',
              style: IqWebText.bodySmall.copyWith(color: IqColors.fg3),
            ),
          ],
        ),
      if (grid.isNotEmpty)
        _Grid(
          columns: columns,
          children: [
            for (final b in grid) _GridCard(brief: b, saved: isSaved(b)),
          ],
        ),
      Padding(
        padding: const EdgeInsets.only(top: IqSpace.s2),
        child: Column(
          children: [
            Text(
              'That’s all ${matching.length} $noun',
              style: IqWebText.bodySmall.copyWith(color: IqColors.fg2),
            ),
            const SizedBox(height: IqSpace.s2),
            _Link(
              narrowed
                  ? 'Clear filters'
                  : saved
                  ? 'Browse briefs'
                  : 'Adjust interests',
              onTap: narrowed
                  ? _clearFilters
                  : saved
                  ? () => ref.read(tabletSavedLensProvider.notifier).set(false)
                  : () => context.open(Routes.yourDetails),
            ),
          ],
        ),
      ),
    ];
  }
}

class _ClosingSoon extends StatelessWidget {
  const _ClosingSoon({
    required this.briefs,
    required this.allSaved,
    required this.anySaved,
    required this.expanded,
    required this.onSeeSaved,
  });

  final List<Brief> briefs;
  final bool allSaved;
  final bool anySaved;
  final bool expanded;
  final VoidCallback onSeeSaved;

  @override
  Widget build(BuildContext context) {
    final n = briefs.length;
    final when = switch (n) {
      1 => 'It closes within 2 days.',
      2 => 'Both close within 2 days.',
      _ => '$n close within 2 days.',
    };
    final yours = allSaved
        ? (n == 1 ? ' You saved it.' : ' You saved them.')
        : '';
    final intro = Padding(
      padding: const EdgeInsets.only(top: IqSpace.s1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Closing soon',
            style: IqText.title.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s2),
          Text(
            '$when$yours',
            style: IqWebText.bodySmall.copyWith(color: IqColors.fg2),
          ),
          if (anySaved) ...[
            const SizedBox(height: IqSpace.s2),
            _Link('See saved briefs', onTap: onSeeSaved),
          ],
        ],
      ),
    );
    final tickets = Wrap(
      spacing: IqSpace.s6,
      runSpacing: IqSpace.s6,
      children: [
        for (final b in briefs.take(expanded ? 2 : 4))
          BriefTicket(brief: b, kind: IqTicketCardKind.hero),
      ],
    );
    if (!expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          intro,
          const SizedBox(height: IqSpace.s4),
          tickets,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: intro),
        const SizedBox(width: IqSpace.s6),
        tickets,
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = (children.length / columns).ceil();
    return Column(
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: IqSpace.s6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: IqSpace.s6),
                Expanded(
                  child: r * columns + c < children.length
                      ? children[r * columns + c]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _GridCard extends ConsumerWidget {
  const _GridCard({required this.brief, required this.saved});

  final Brief brief;
  final bool saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final left = timeLeft(brief.deadline, now);
    final closed = !brief.isLive || (left != null && left <= Duration.zero);
    return LayoutBuilder(
      builder: (context, constraints) => IqBriefCard(
        kind: IqBriefCardKind.carousel,
        widthOverride: constraints.maxWidth,
        brand: businessLabel(brief),
        title: brief.title,
        cover: businessCover(brief.cover),
        logo: businessLogo(brief.logo),
        meta: [
          IqMeta(
            kind: IqMetaKind.reward,
            label: rewardShort(brief.rewardPoolKobo),
          ),
          if (closed || left != null)
            IqMeta(
              kind: !closed && left! <= DeadlineRules.closingSoon
                  ? IqMetaKind.urgent
                  : IqMetaKind.deadline,
              label: closesIn(left, closed: closed),
            ),
        ],
        closingSoon: isClosingSoon(brief, now),
        showBookmark: Flags.savedBriefs,
        bookmark: saved ? IqBookmarkState.on : IqBookmarkState.off,
        onBookmarkChanged: (state) => ref
            .read(savedBriefsProvider.notifier)
            .setSaved(brief, state == IqBookmarkState.on),
        onTap: () => context.open(Routes.brief(brief.id), extra: brief),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.label, {this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      tactile: false,
      semanticLabel: label,
      builder: (context, pressed) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(
          widthFactor: 1,
          heightFactor: 1,
          child: Opacity(
            opacity: pressed ? 0.6 : 1,
            child: Text(
              label,
              style: IqWebText.bodySmallStrong.copyWith(
                color: IqColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bones extends StatelessWidget {
  const _Bones({required this.widths});

  final List<double> widths;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, w) in widths.indexed) ...[
          SizedBox(height: i == 0 ? 0 : IqSpace.s4),
          Container(
            width: w,
            height: 12,
            decoration: BoxDecoration(
              color: IqColors.secondary,
              borderRadius: BorderRadius.circular(IqRadius.sm),
            ),
          ),
        ],
      ],
    );
  }
}

class _CardBones extends StatelessWidget {
  const _CardBones();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(IqRadius.xl2),
        border: Border.all(color: IqColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 164, color: IqColors.panel),
          const Padding(
            padding: EdgeInsets.all(IqSpace.s4),
            child: _Bones(widths: [110, 220, 170, 150]),
          ),
        ],
      ),
    );
  }
}

/// The filter popover: two columns in portrait with Show at the foot,
/// three in landscape with Show beside Clear all.
class _FiltersPopover extends StatelessWidget {
  const _FiltersPopover({
    required this.draft,
    required this.live,
    required this.now,
    required this.wide,
    required this.onChanged,
    required this.onShow,
  });

  final TabletFilters draft;
  final List<Brief> live;
  final DateTime now;
  final bool wide;
  final ValueChanged<TabletFilters> onChanged;
  final VoidCallback onShow;

  int _count(bool Function(Brief) test) => live.where(test).length;

  @override
  Widget build(BuildContext context) {
    final shown = live.where((b) => draft.matches(b, now)).length;
    final pools = [for (final b in live) b.rewardPoolKobo];
    final lo = pools.isEmpty ? 0 : pools.reduce(math.min);
    final hi = pools.isEmpty ? 0 : pools.reduce(math.max);
    final span = math.max(1, hi - lo);
    final min = draft.minKobo ?? lo;
    final max = draft.maxKobo ?? hi;

    Widget group(String title, List<Widget> options) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: IqWebText.bodySmallStrong.copyWith(color: IqColors.fg),
        ),
        const SizedBox(height: IqSpace.s1),
        ...options,
      ],
    );

    final closes = group('Closes', [
      for (final c in ClosesWithin.values)
        IqWebFilterOption(
          label: c.label,
          type: IqWebFilterOptionType.radio,
          on: draft.closes == c,
          count: '${_count((b) => TabletFilters(closes: c).matches(b, now))}',
          onChanged: (_) => onChanged(draft.copyWith(closes: c)),
        ),
    ]);
    final reward = group('Reward pool', [
      IqWebRangeField(
        min: rewardPool(min),
        max: rewardPool(max),
        values: RangeValues((min - lo) / span, (max - lo) / span),
        onChanged: (v) {
          int at(double t) => ((lo + t * span) / 1000000).round() * 1000000;
          final a = at(v.start), b = at(v.end);
          onChanged(
            draft.copyWith(
              minKobo: () => a <= lo ? null : a,
              maxKobo: () => b >= hi ? null : b,
            ),
          );
        },
      ),
    ]);
    final tier = group('Tier', [
      for (final t in Tier.values)
        IqWebFilterOption(
          label: t.label,
          on: draft.tiers.contains(t),
          count: '${_count((b) => b.tier == t)}',
          onChanged: (on) => onChanged(
            draft.copyWith(
              tiers: on ? {...draft.tiers, t} : ({...draft.tiers}..remove(t)),
            ),
          ),
        ),
    ]);
    final category = group('Category', [
      for (final c in Category.values)
        if (c != Category.other || live.any((b) => b.category == c))
          IqWebFilterOption(
            label: c.label,
            on: draft.categories.contains(c),
            count: '${_count((b) => b.category == c)}',
            onChanged: (on) => onChanged(
              draft.copyWith(
                categories: on
                    ? {...draft.categories, c}
                    : ({...draft.categories}..remove(c)),
              ),
            ),
          ),
    ]);
    final present = {for (final b in live) ?b.interest};
    final interests = group('Interests', [
      for (final value in present)
        IqWebFilterOption(
          label: filterInterestLabel(value),
          on: draft.interests.contains(value),
          count: '${_count((b) => b.interest == value)}',
          onChanged: (on) => onChanged(
            draft.copyWith(
              interests: on
                  ? {...draft.interests, value}
                  : ({...draft.interests}..remove(value)),
            ),
          ),
        ),
    ]);

    final show = IqButton(
      label: 'Show $shown ${shown == 1 ? 'brief' : 'briefs'}',
      showIcon: false,
      width: 180,
      rollLabel: true,
      onTap: onShow,
    );
    final clear = _Link(
      'Clear all',
      onTap: () => onChanged(const TabletFilters()),
    );
    const gap = SizedBox(height: IqSpace.s5);
    final columns = wide
        ? [
            Column(children: [closes, gap, tier]),
            Column(children: [category, gap, reward]),
            Column(children: [interests]),
          ]
        : [
            Column(children: [closes, gap, reward, gap, tier]),
            Column(children: [category, gap, interests]),
          ];

    return Container(
      width: wide ? 768 : 520,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(IqRadius.xl),
        border: Border.all(color: IqColors.line),
        boxShadow: IqShadows.lg,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(IqSpace.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filters',
                    style: IqWebText.headingCardSection.copyWith(
                      color: IqColors.fg,
                    ),
                  ),
                ),
                clear,
                if (wide) ...[const SizedBox(width: IqSpace.s5), show],
              ],
            ),
            const SizedBox(height: IqSpace.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, c) in columns.indexed) ...[
                  if (i > 0) const SizedBox(width: IqSpace.s6),
                  Expanded(child: c),
                ],
              ],
            ),
            if (!wide) ...[
              const SizedBox(height: IqSpace.s3),
              Align(alignment: Alignment.centerRight, child: show),
            ],
          ],
        ),
      ),
    );
  }
}
