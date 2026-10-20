import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/activations_data.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/bookmark.dart';
import '../../ui/brief_card.dart';
import '../../ui/chip.dart';
import '../../ui/empty_state.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/meta.dart';
import '../../ui/sample_cover.dart';
import '../../ui/sample_logo.dart';
import '../../ui/section_title.dart';
import '../../ui/top_bar.dart';
import '../activations/activation_format.dart';
import '../activations/activations_state.dart';
import '../discover/business_art.dart' show businessCover;
import '../discover/discover_state.dart';
import '../discover/filters_sheet.dart';
import 'submit_parts.dart';

enum PickLens { forYou, all, saved }

/// The briefs a lens lists, flat: For you is Discover's For you order
/// (closing soon, the interest groups, then the rest); All is every open
/// brief, closing soonest first; Saved is the saved ones.
List<Brief> pickList({
  required PickLens lens,
  required List<Brief> briefs,
  required List<Brief> saved,
  required DiscoverFilters filters,
  required List<String> interests,
  required DateTime now,
}) {
  if (lens == PickLens.saved) return saved;
  final view = buildFeed(
    briefs: briefs,
    filters: filters.copyWith(
      sort: lens == PickLens.forYou
          ? FeedSort.myInterests
          : FeedSort.mostUrgent,
    ),
    interests: interests,
    now: now,
    window: briefs.length,
  );
  final seen = <String>{};
  return [
    for (final brief in [...view.briefs.briefs, ...view.more.briefs])
      if (seen.add(brief.id)) brief,
  ];
}

/// B3 · Discover · pick a brief (409:75), a sub page opened from My
/// submissions with nothing sent: the feed lenses, the activation closing
/// first (preview launches only) and the briefs to answer. A brief opens its detail, where the
/// response starts.
class PickBriefScreen extends ConsumerStatefulWidget {
  const PickBriefScreen({super.key});

  @override
  ConsumerState<PickBriefScreen> createState() => _PickBriefScreenState();
}

class _PickBriefScreenState extends ConsumerState<PickBriefScreen> {
  PickLens _lens = PickLens.forYou;

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.submissions, extra: NavDirection.back);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(discoverFeedProvider);
    final saved = ref.watch(savedBriefsProvider).value ?? const <Brief>[];
    final activations = ref.watch(activationsShownProvider)
        ? ref.watch(activationsProvider).value
        : null;
    final now = ref.watch(clockProvider)();
    final filters = ref.watch(discoverFiltersProvider);
    List<Brief> list(PickLens lens) => pickList(
      lens: lens,
      briefs: feed.value?.briefs ?? const [],
      saved: saved,
      filters: filters,
      interests: ref.watch(feedInterestsProvider),
      now: now,
    );
    final briefs = list(_lens);
    final activation = _lens == PickLens.saved
        ? null
        : _firstOpen(activations, now);
    final empty =
        briefs.isEmpty && activation == null && feed.hasValue && !feed.hasError;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          bottom: false,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Pick a brief',
                  showTrailing: true,
                  trailingIcon: IqIcons.filter,
                  onBack: _leave,
                  onTrailing: () => showIqSheet<void>(
                    context,
                    (_) => const FiltersSheet(),
                    scrim: IqScrim.sheet,
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: IqSpace.s4,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              for (final (i, lens)
                                  in PickLens.values.indexed) ...[
                                if (i > 0) const SizedBox(width: IqSpace.s2),
                                IqChip(
                                  label: _label(lens),
                                  state: lens == _lens
                                      ? IqChipState.selected
                                      : IqChipState.standard,
                                  onChanged: (_) =>
                                      setState(() => _lens = lens),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (empty)
                        IqSliverEmptyFill(
                          key: ValueKey(('empty', _lens)),
                          bottom: MediaQuery.paddingOf(context).bottom,
                          child: _empty(
                            filters,
                            others: list(PickLens.all).isNotEmpty,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            IqSpace.s4,
                            IqSpace.s3 * 3,
                            IqSpace.s4,
                            IqSpace.s6 + MediaQuery.paddingOf(context).bottom,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _content(
                              feed: feed,
                              briefs: briefs,
                              saved: saved,
                              activation: activation,
                              now: now,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// With nothing to pick, the shared empty state. Its button only leads
  /// somewhere else: filters can be cleared, and Saved points to All when
  /// All has briefs.
  Widget _empty(DiscoverFilters filters, {required bool others}) {
    if (_lens == PickLens.saved) {
      return IqEmptyState(
        figure: IqFigures.saver,
        title: 'Nothing saved yet',
        body: 'Tap the bookmark on any brief.',
        action: 'See all briefs',
        onAction: others ? () => setState(() => _lens = PickLens.all) : null,
      );
    }
    final narrowed = filters.narrowed;
    return IqEmptyState(
      figure: narrowed ? IqFigures.shrug : IqFigures.writer,
      title: narrowed
          ? 'No briefs match these filters'
          : 'No open briefs right now',
      body: narrowed ? null : 'New briefs land here.',
      action: 'Clear filters',
      onAction: narrowed
          ? () => ref
                .read(discoverFiltersProvider.notifier)
                .apply(const DiscoverFilters())
          : null,
    );
  }

  Widget _content({
    required AsyncValue<Object?> feed,
    required List<Brief> briefs,
    required List<Brief> saved,
    required Activation? activation,
    required DateTime now,
  }) {
    return AnimatedSwitcher(
      duration: motion(context, IqDurations.swap),
      switchInCurve: IqCurves.easeOut,
      switchOutCurve: IqCurves.easeOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: Column(
        key: ValueKey(_lens),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (activation != null) ...[
            IqSectionTitle(
              title: 'Activations',
              onSeeAll: () => context.open(Routes.activations),
            ),
            const SizedBox(height: IqSpace.s3),
            _ActivationCard(activation: activation, now: now),
            const SizedBox(height: IqSpace.s3 * 3),
          ],
          IqSectionTitle(
            title: 'Briefs',
            link: 'Filter',
            onSeeAll: () => showIqSheet<void>(
              context,
              (_) => const FiltersSheet(),
              scrim: IqScrim.sheet,
            ),
          ),
          if (feed.hasError && briefs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: IqSpace.s3),
              child: IqBanner(
                kind: IqBannerKind.error,
                title: 'Couldn’t load. Check your connection.',
                action: 'Try again',
                onAction: () => ref.read(discoverFeedProvider.notifier).retry(),
              ),
            ),
          for (final brief in briefs) ...[
            const SizedBox(height: IqSpace.s3),
            _BriefCard(
              brief: brief,
              now: now,
              saved: saved.any((b) => b.id == brief.id),
              onSaved: (on) =>
                  ref.read(savedBriefsProvider.notifier).setSaved(brief, on),
            ),
          ],
        ],
      ),
    );
  }

  static String _label(PickLens lens) => switch (lens) {
    PickLens.forYou => 'For you',
    PickLens.all => 'All',
    PickLens.saved => 'Saved',
  };

  static Activation? _firstOpen(List<Activation>? list, DateTime now) {
    final open = [
      for (final a in list ?? const <Activation>[])
        if (!a.started && a.closesAt.isAfter(now)) a,
    ]..sort((a, b) => a.closesAt.compareTo(b.closesAt));
    return open.firstOrNull;
  }
}

class _BriefCard extends StatelessWidget {
  const _BriefCard({
    required this.brief,
    required this.now,
    required this.saved,
    required this.onSaved,
  });

  final Brief brief;
  final DateTime now;
  final bool saved;
  final ValueChanged<bool> onSaved;

  @override
  Widget build(BuildContext context) {
    final brand = sampleBrandOf(brief);
    final left = timeLeft(brief.deadline, now);
    final soon =
        left != null &&
        left > Duration.zero &&
        left <= DeadlineRules.closingSoon;
    return IqBriefCard(
      brand: brief.businessName ?? 'Private business',
      title: brief.title,
      cover: IqSampleCover(brand),
      logo: IqSampleLogo(brand),
      closingSoon: soon,
      showBookmark: Flags.savedBriefs,
      bookmark: saved ? IqBookmarkState.on : IqBookmarkState.off,
      onBookmarkChanged: (state) => onSaved(state == IqBookmarkState.on),
      meta: [
        IqMeta(kind: IqMetaKind.reward, label: poolShort(brief.rewardPoolKobo)),
        IqMeta(
          kind: soon ? IqMetaKind.urgent : IqMetaKind.deadline,
          label: closesIn(left),
        ),
      ],
      onTap: () => context.open(Routes.brief(brief.id), extra: brief),
    );
  }
}

class _ActivationCard extends StatelessWidget {
  const _ActivationCard({required this.activation, required this.now});

  final Activation activation;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return IqBriefCard(
      kind: IqBriefCardKind.row,
      brand: activation.business,
      title: activation.title,
      cover: activation.live
          ? businessCover(activation.imageUrl)
          : IqSampleCover(businessArt(activation.business)),
      logo: activationLogoArt(activation),
      meta: [
        IqMeta(
          kind: IqMetaKind.reward,
          label: cardReward(activation, poolShort(activation.rewardKobo)),
        ),
        IqMeta(
          kind: IqMetaKind.urgent,
          label: 'Closes in ${countdownText(activationLeft(activation, now))}',
        ),
      ],
      onTap: () => context.open('${Routes.activations}/${activation.id}'),
    );
  }
}
