import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/points_data.dart';
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/leaderboard_row.dart';
import '../../ui/podium.dart';
import '../../ui/top_bar.dart';
import 'leaderboard_screen.dart';
import 'outcomes_state.dart';
import 'result_screen.dart';

final pointsBoardProvider = FutureProvider.autoDispose<PointsBoard>(
  (ref) => ref.watch(repositoryProvider).pointsLeaderboard(),
);

String pointsLabel(int points) => '${wholeNumber(points)} pts';

/// "2 wins · 5 submissions", "1 win · 22 submissions".
String winsAndSubmissions(int wins, int submissions) => [
  wins == 1 ? '1 win' : '$wins wins',
  submissions == 1 ? '1 submission' : '$submissions submissions',
].join(' · ');

/// B13 · Leaderboard · iQL points (548:25018), a sub page: all contributors
/// this month, "You are 7th of 2,130", the podium in points, then every
/// other rank from fourth down with wins and submissions, the contributor
/// highlighted in place. How points work opens the Help centre. Opened
/// from the pass's points field and the More quick link Leaderboard.
class PointsLeaderboardScreen extends ConsumerWidget {
  const PointsLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(pointsBoardProvider).value;
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
                  title: 'iQL points',
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go(Routes.more, extra: NavDirection.back),
                ),
                Expanded(
                  child: board == null
                      ? const SizedBox.shrink()
                      : _Board(board: board),
                ),
                ResultActions(
                  children: [
                    IqButton(
                      label: 'How points work',
                      kind: IqButtonKind.ghost,
                      showIcon: false,
                      width: double.infinity,
                      onTap: () => context.open(Routes.helpCentre),
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

  final PointsBoard board;

  @override
  Widget build(BuildContext context) {
    final podium = board.entries.take(3).toList();
    final rows = board.entries.skip(3).toList();
    String name(int i) => i < podium.length ? podium[i].name : '';
    String points(int i) =>
        i < podium.length ? pointsLabel(podium[i].points) : '';
    final you = board.you;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(IqSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'All contributors · ${DateFormat('MMMM').format(board.month)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: IqText.smallStrong.copyWith(color: IqColors.fg2),
          ),
          const SizedBox(height: IqSpace.s3),
          if (you != null)
            Text(
              'You are ${ordinal(you.rank)} of '
              '${wholeNumber(board.contributors)}',
              style: IqText.title.copyWith(color: IqColors.fg),
            ),
          const SizedBox(height: IqSpace.s3),
          IqPodium(
            name1: name(0),
            amount1: points(0),
            avatar1: leaderboardAvatar(name(0), 64),
            name2: name(1),
            amount2: points(1),
            avatar2: leaderboardAvatar(name(1), 52),
            name3: name(2),
            amount3: points(2),
            avatar3: leaderboardAvatar(name(2), 52),
          ),
          const SizedBox(height: IqSpace.s3 * 3),
          Stagger(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, row) in rows.indexed) ...[
                  if (i > 0) const SizedBox(height: IqLeaderboardRow.gap),
                  StaggerItem(
                    index: i,
                    child: MergeSemantics(
                      child: IqLeaderboardRow(
                        rank: '${row.rank}',
                        name: row.name,
                        entry: winsAndSubmissions(row.wins, row.submissions),
                        amount: pointsLabel(row.points),
                        state: row.you
                            ? IqLeaderboardRowState.you
                            : IqLeaderboardRowState.standard,
                        rankDelay: row.you && i < Stagger.moving
                            ? IqDurations.stagger * i + IqDurations.chain
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
