import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../data/polls_data.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/biz_segment.dart';
import '../../ui/button.dart';
import '../../ui/empty_state.dart';
import '../../ui/illustration.dart';
import '../../ui/web_poll_row.dart';
import '../discover/business_art.dart';
import '../shell/tablet_page.dart';
import '../shell/tablet_sheet.dart';
import 'polls_routes.dart';
import 'polls_state.dart';

/// T9 · Polls (Mobile App · tablet, 1841:46774): Open polls and Answered,
/// each a card of Exp/Web/PollRow. A row opens its business's polls as the
/// 560 dialog over the scrim.
class TabletPolls extends ConsumerStatefulWidget {
  const TabletPolls({super.key});

  @override
  ConsumerState<TabletPolls> createState() => _TabletPollsState();
}

class _TabletPollsState extends ConsumerState<TabletPolls> {
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    final polls = ref.watch(pollsProvider);
    final data = polls.hasValue && !polls.hasError && !polls.isReloading
        ? polls.value
        : null;
    final now = ref.watch(clockProvider)();
    final history = _completed ? ref.watch(pollHistoryProvider) : null;
    final historyPage = pollHistoryFor(history, ref.watch(accountProvider));
    final shown = pollTiles(
      mergePollBusinesses(
        historyPage?.businesses ?? const [],
        data ?? const [],
      ),
      completed: _completed,
      now: now,
    );

    Widget group(String title, List<PollBusiness> businesses) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(title, style: IqText.title.copyWith(color: IqColors.fg)),
            const SizedBox(width: IqSpace.s2),
            Text(
              '${businesses.length}',
              style: IqWebText.bodySmall.copyWith(color: IqColors.fg3),
            ),
          ],
        ),
        const SizedBox(height: IqSpace.s4),
        TabletCard(
          child: Column(
            children: [
              for (final (i, b) in businesses.indexed) ...[
                if (i > 0)
                  const SizedBox(
                    height: 1,
                    child: ColoredBox(color: IqColors.line),
                  ),
                Opacity(
                  opacity: pollsClosed(b, now) && !_completed ? 0.5 : 1,
                  child: IqWebPollRow(
                    business: b.name,
                    question: b.headline,
                    detail: pollDetail(b),
                    closes: closesIn(
                      timeLeft(b.firstClose, now),
                      closed: pollsClosed(b, now),
                    ),
                    cover: businessCover(b.cover),
                    logo: businessLogo(b.logo),
                    status: b.allAnswered
                        ? IqWebPollRowStatus.answered
                        : IqWebPollRowStatus.open,
                    onTap: pollsClosed(b, now) && !_completed
                        ? null
                        : () => context.open(
                            pollsOf(
                              b.id,
                              pollId: b.polls.single.id,
                              history: _completed,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return TabletPage(
      title: 'Quick polls',
      subtitle:
          'Each poll takes seconds. Businesses share the results in about a week.',
      children: [
        IqBizSegment.track(
          children: [
            IqBizSegment(
              label: 'Available',
              state: !_completed
                  ? IqBizSegmentState.selected
                  : IqBizSegmentState.standard,
              onTap: () => setState(() => _completed = false),
            ),
            IqBizSegment(
              label: 'Completed',
              state: _completed
                  ? IqBizSegmentState.selected
                  : IqBizSegmentState.standard,
              onTap: () => setState(() => _completed = true),
            ),
          ],
        ),
        Text(
          _completed
              ? 'Thank you for answering honestly.'
              : 'Your answers are valuable. Please answer honestly.',
          style: IqWebText.bodySmall.copyWith(color: IqColors.fg3),
        ),
        if ((_completed ? history?.hasError == true : polls.hasError) &&
            shown.isEmpty)
          IqBanner(
            kind: IqBannerKind.error,
            title: "Couldn't load. Check your connection.",
            action: 'Try again',
            onAction: () {
              if (_completed) {
                ref.invalidate(pollHistoryProvider);
              } else {
                ref.read(pollsProvider.notifier).retry();
              }
            },
          )
        else if ((_completed
                ? history != null && historyPage == null && !history.hasError
                : data == null) &&
            shown.isEmpty)
          const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: IqColors.primary),
            ),
          )
        else if (shown.isEmpty)
          IqEmptyState(
            figure: IqFigures.shrug,
            title: _completed
                ? historyPage?.nextCursor != null
                      ? 'No completed polls on this page'
                      : 'No completed polls yet'
                : 'No open polls right now',
            body: _completed
                ? historyPage?.nextCursor != null
                      ? 'Load more to keep looking.'
                      : 'Polls you answer will appear here.'
                : 'New polls land here.',
          )
        else ...[
          group(_completed ? 'Completed polls' : 'Open polls', shown),
        ],
        if (_completed && history?.hasError == true && shown.isNotEmpty)
          IqBanner(
            kind: IqBannerKind.error,
            title: "Couldn't load older polls.",
            action: 'Try again',
            onAction: () => ref.invalidate(pollHistoryProvider),
          ),
        if (_completed && historyPage?.nextCursor != null)
          IqButton(
            label: historyPage!.loadMoreFailed ? 'Try again' : 'Load more',
            kind: IqButtonKind.secondary,
            showIcon: false,
            loading: historyPage.loadingMore,
            onTap: () => ref.read(pollHistoryProvider.notifier).loadMore(),
          ),
      ],
    );
  }
}
