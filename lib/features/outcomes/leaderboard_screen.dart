import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/leaderboard_row.dart';
import '../../ui/top_bar.dart';
import '../submissions/submissions_routes.dart';
import 'outcomes_state.dart';
import 'result_screen.dart';

/// B13 · Leaderboard (193:9779) and Leaderboard · not selected (225:10747):
/// the brief, "Top 5 of 48 entries", the paid places with the pool they
/// split under them, then the rows below the cut. The rows arrive 40 apart,
/// the cutoff line draws in on its turn and the contributor's orange rank
/// disc pops at its row's arrival + 120 (MOTION-SPEC §5.33). Open the brief
/// goes to Brief detail.
///
/// Figma over its frames: the eyebrow is the brief's title on both boards
/// (225:10747 shows the entry's); back returns to the result it came from
/// (225:10747 points it at the Winner).
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(resultProvider(id)).value;
    final board = data == null ? null : Leaderboard.of(data);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Leaderboard',
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go(resultPath(id), extra: NavDirection.back),
                ),
                Expanded(
                  child: board == null
                      ? const SizedBox.shrink()
                      : _Board(board: board),
                ),
                if (board != null)
                  ResultActions(
                    children: [
                      IqButton(
                        label: 'Open the brief',
                        kind: IqButtonKind.ghost,
                        showIcon: false,
                        width: double.infinity,
                        onTap: () => context.push(Routes.brief(board.brief.id)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.board});

  final Leaderboard board;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(IqSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            board.brief.title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: IqText.mono.copyWith(color: IqColors.fg2),
          ),
          const SizedBox(height: IqSpace.s3),
          Text(board.title, style: IqText.title.copyWith(color: IqColors.fg)),
          const SizedBox(height: IqSpace.s3),
          Stagger(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, item) in board.items.indexed) ...[
                  if (i > 0) const SizedBox(height: IqLeaderboardRow.gap),
                  StaggerItem(index: i, child: _item(item, i)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(BoardItem item, int index) => switch (item) {
    BoardRow(:final entry, :final you) => MergeSemantics(
      child: IqLeaderboardRow(
        rank: '${entry.rank}',
        name: entry.name,
        entry: entry.entry,
        amount: entry.amountKobo == null ? '' : rewardPool(entry.amountKobo!),
        showAmount: entry.amountKobo != null,
        state: you ? IqLeaderboardRowState.you : IqLeaderboardRowState.standard,
        rankDelay: you && index < Stagger.moving
            ? IqDurations.stagger * index + IqDurations.chain
            : null,
      ),
    ),
    BoardCutoff() => SizedBox(
      height: 40,
      child: Center(
        child: Wipe(
          delay: IqDurations.stagger * index,
          child: Text(
            item.label,
            style: IqText.mono.copyWith(color: IqColors.fg2),
          ),
        ),
      ),
    ),
    BoardGap() => SizedBox(
      height: 28,
      child: Center(
        child: ExcludeSemantics(
          child: Text(
            '· · ·',
            style: IqText.mono.copyWith(color: IqColors.fg2),
          ),
        ),
      ),
    ),
  };
}
