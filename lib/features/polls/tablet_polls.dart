import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/navigation.dart';
import '../../data/polls_data.dart';
import '../../theme/theme.dart';
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
class TabletPolls extends ConsumerWidget {
  const TabletPolls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final polls = ref.watch(pollsProvider);
    final data = polls.hasValue && !polls.hasError ? polls.value : null;
    final now = ref.watch(clockProvider)();
    final open = [
      for (final b in data ?? const <PollBusiness>[])
        if (!b.allAnswered) b,
    ];
    final answered = [
      for (final b in data ?? const <PollBusiness>[])
        if (b.allAnswered) b,
    ];

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
                  opacity: pollsClosed(b, now) ? 0.5 : 1,
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
                    onTap: pollsClosed(b, now)
                        ? null
                        : () => context.open(pollsOf(b.id)),
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
      subtitle: 'Each poll takes seconds. Businesses share the results in about a week.',
      children: [
        if (data == null && polls.hasError)
          const IqEmptyState(
            figure: IqFigures.thinker,
            title: 'Nothing to show yet',
            body: 'They will show here once they load.',
          )
        else if (data == null)
          const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: IqColors.primary),
            ),
          )
        else if (data.isEmpty)
          const IqEmptyState(
            figure: IqFigures.shrug,
            title: 'No open polls right now',
            body: 'New polls land here.',
          )
        else ...[
          if (open.isNotEmpty) group('Open polls', open),
          if (answered.isNotEmpty) group('Answered', answered),
        ],
      ],
    );
  }
}
