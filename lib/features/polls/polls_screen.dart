import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/deadline.dart' show clockProvider;
import '../../core/session.dart';
import '../../data/polls_data.dart';
import '../../theme/theme.dart';
import '../../ui/empty_state.dart';
import '../../ui/illustration.dart';
import '../../ui/banner.dart';
import '../../ui/biz_filter_chip.dart';
import '../../ui/button.dart';
import '../../ui/chip.dart';
import '../../ui/skeleton.dart';
import '../../ui/top_bar.dart';
import '../discover/discover_routes.dart';
import 'polls_routes.dart';
import 'polls_state.dart';
import 'tablet_polls.dart';
import 'quick_poll_tile.dart';

/// B2 · Quick polls (33:26), behind Flags.polls: a sub page with the open
/// polls as Exp/PollTile, each raising its business's sheet. Opened from a
/// Discover tile, [open] names the business and its sheet rises over this
/// page, as Figma's tiles lead to 33:169. A notification names its poll
/// instead; one the list does not hold is read on its own first.
///
/// The tiles arrive the first time the list shows in a session (MOTION-SPEC
/// §7.3) and stand still on later visits.
class PollsScreen extends ConsumerStatefulWidget {
  const PollsScreen({super.key, this.open});

  final String? open;

  @override
  ConsumerState<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends ConsumerState<PollsScreen> {
  bool _opened = false;
  bool _completed = false;
  PollListSort _sort = PollListSort.closing;

  @override
  void initState() {
    super.initState();
    ref.read(pollsProvider.notifier).refreshQuietly().ignore();
  }

  Future<void> _pickSort(BuildContext context) async {
    final next = await showModalBottomSheet<PollListSort>(
      context: context,
      backgroundColor: IqColors.card,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final sort in PollListSort.values)
              ListTile(
                title: Text(sort.label),
                onTap: () => Navigator.pop(context, sort),
              ),
          ],
        ),
      ),
    );
    if (next != null && mounted) setState(() => _sort = next);
  }

  void _openFromBubble(List<PollBusiness> businesses) {
    final open = widget.open;
    if (_opened || open == null) return;
    _opened = true;
    final business = businesses
        .where(
          (b) =>
              b.name == open ||
              b.id == open ||
              b.polls.any((p) => p.id == open),
        )
        .firstOrNull;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id =
          business?.id ??
          (mounted ? await ref.read(pollsProvider.notifier).bring(open) : null);
      if (mounted && id != null) context.open(pollsOf(id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final polls = ref.watch(pollsProvider);
    final data = polls.hasValue && !polls.hasError && !polls.isReloading
        ? polls.value
        : null;
    final failed = data == null && polls.hasError && !polls.isLoading;
    if (data != null) _openFromBubble(data);
    if (Layout.isTablet(context)) return const TabletPolls();
    final history = _completed ? ref.watch(pollHistoryProvider) : null;
    final historyPage = pollHistoryFor(history, ref.watch(accountProvider));
    final all = mergePollBusinesses(
      historyPage?.businesses ?? const [],
      data ?? const [],
    );
    final now = ref.watch(clockProvider)();
    final shown = sortPollTiles([
      for (final business in pollTiles(all, completed: _completed, now: now))
        business,
    ], _sort);
    final historyFailed = history?.hasError ?? false;
    final loading = _completed
        ? shown.isEmpty &&
              history != null &&
              historyPage == null &&
              !historyFailed
        : data == null && !failed;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: IqColors.bg,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Quick polls',
                  onBack: () => leave(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    0,
                    IqSpace.s4,
                    IqSpace.s3,
                  ),
                  child: Wrap(
                    spacing: IqSpace.s2,
                    runSpacing: IqSpace.s2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IqChip(
                        label: 'Available',
                        state: !_completed
                            ? IqChipState.selected
                            : IqChipState.standard,
                        onChanged: (_) => setState(() => _completed = false),
                      ),
                      IqChip(
                        label: 'Completed',
                        state: _completed
                            ? IqChipState.selected
                            : IqChipState.standard,
                        onChanged: (_) => setState(() => _completed = true),
                      ),
                      IqBizFilterChip(
                        label: 'Sort: ${_sort.label}',
                        onTap: () => _pickSort(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LoadingGate(
                    loading: loading,
                    skeleton: const _Skeleton(),
                    child:
                        (_completed ? historyFailed && shown.isEmpty : failed)
                        ? _Failed(
                            onRetry: () {
                              if (_completed) {
                                ref.invalidate(pollHistoryProvider);
                              } else {
                                ref.read(pollsProvider.notifier).retry();
                              }
                            },
                          )
                        : loading
                        ? const SizedBox.shrink()
                        : shown.isEmpty
                        ? _completed && historyPage?.nextCursor != null
                              ? const _MoreHistory()
                              : _Empty(completed: _completed)
                        : _Businesses(businesses: shown, history: _completed),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(IqSpace.s4, 0, IqSpace.s4, IqSpace.s4),
      children: [...children],
    );
  }
}

class _Businesses extends ConsumerStatefulWidget {
  const _Businesses({required this.businesses, required this.history});

  final List<PollBusiness> businesses;
  final bool history;

  @override
  ConsumerState<_Businesses> createState() => _BusinessesState();
}

class _BusinessesState extends ConsumerState<_Businesses> {
  late final bool _arrive = !ref.read(pollsArrivedProvider);

  @override
  void initState() {
    super.initState();
    if (_arrive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(pollsArrivedProvider.notifier).arrived();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final businesses = widget.businesses;
    return Stagger(
      play: _arrive,
      child: _Page(
        children: [
          for (final (i, business) in businesses.indexed) ...[
            if (i > 0) const SizedBox(height: IqSpace.s2p5),
            StaggerItem(
              index: i,
              child: QuickPollTile(
                key: ValueKey(business.polls.single.id),
                business: business,
                showResults: widget.history,
                onTap: () => context.open(
                  pollsOf(
                    business.id,
                    pollId: business.polls.single.id,
                    history: widget.history,
                  ),
                ),
              ),
            ),
          ],
          if (widget.history) ...[
            const SizedBox(height: IqSpace.s3),
            const _HistoryFooter(),
          ],
        ],
      ),
    );
  }
}

class _MoreHistory extends StatelessWidget {
  const _MoreHistory();

  @override
  Widget build(BuildContext context) => const _Page(
    children: [
      IqEmptyState(
        figure: IqFigures.shrug,
        title: 'No completed polls on this page',
      ),
      SizedBox(height: IqSpace.s3),
      _HistoryFooter(),
    ],
  );
}

class _HistoryFooter extends ConsumerWidget {
  const _HistoryFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(pollHistoryProvider);
    if (history.hasError) {
      return IqBanner(
        kind: IqBannerKind.error,
        title: "Couldn't load older polls.",
        action: 'Try again',
        onAction: () => ref.invalidate(pollHistoryProvider),
      );
    }
    final page = pollHistoryFor(history, ref.watch(accountProvider));
    if (page?.nextCursor == null) return const SizedBox.shrink();
    return IqButton(
      label: page!.loadMoreFailed ? 'Try again' : 'Load more',
      kind: IqButtonKind.secondary,
      showIcon: false,
      loading: page.loadingMore,
      width: double.infinity,
      onTap: () => ref.read(pollHistoryProvider.notifier).loadMore(),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return _Page(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: IqSpace.s3),
          const IqSkeleton(kind: IqSkeletonKind.row),
        ],
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Page(
      children: [
        IqBanner(
          kind: IqBannerKind.error,
          title: 'Couldn’t load. Check your connection.',
          action: 'Try again',
          onAction: onRetry,
        ),
        const SizedBox(height: IqSpace.s6),
        const _Note(
          title: 'Nothing to show yet',
          body: 'They will show here once they load.',
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    return IqEmptyFill(
      child: IqEmptyState(
        figure: IqFigures.shrug,
        title: completed ? 'No completed polls yet' : 'No open polls right now',
        body: completed
            ? 'Polls you answer will appear here.'
            : 'New polls land here.',
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: IqText.cardTitle.copyWith(color: IqColors.fg),
        ),
        const SizedBox(height: IqSpace.s2),
        Text(
          body,
          textAlign: TextAlign.center,
          style: IqText.body.copyWith(color: IqColors.fg2),
        ),
      ],
    );
  }
}
