import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../data/polls_data.dart';
import '../../ui/poll_tile.dart';
import '../discover/business_art.dart';
import 'polls_state.dart';

/// A business's quick poll as an Exp/PollTile (Horizontal): its first
/// question and how many there are, or Answered once all are. A business
/// whose polls have all closed dims to half and takes no taps (480:22779).
class QuickPollTile extends ConsumerWidget {
  const QuickPollTile({super.key, required this.business, this.onTap});

  final PollBusiness business;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closed = pollsClosed(business, ref.watch(clockProvider)());
    final tile = IqPollTile(
      layout: IqPollTileLayout.horizontal,
      state: business.allAnswered
          ? IqPollTileState.answered
          : IqPollTileState.open,
      question: business.headline,
      meta: business.allAnswered
          ? 'Answered'
          : questions(business.polls.length),
      cover: businessCover(business.cover),
      logo: businessLogo(business.logo),
      onTap: closed ? null : onTap,
    );
    return closed ? Opacity(opacity: 0.5, child: tile) : tile;
  }
}
