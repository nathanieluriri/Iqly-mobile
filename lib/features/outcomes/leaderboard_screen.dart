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
import '../../ui/podium.dart';
import '../../ui/avatar.dart';
import '../../ui/top_bar.dart';
import '../submissions/brief_art.dart';
import '../submissions/submissions_routes.dart';
import 'outcomes_state.dart';
import 'result_screen.dart';

/// B13 · Leaderboard (193:9779) and Leaderboard · not selected (225:10747):
/// the brief, "48 submissions, ranked", the podium, then every rank from
/// fourth down in one scrolling list with your row highlighted in place;
/// amounts only on paid ranks (designer doc rev 57). The rows arrive 40
/// apart and the contributor's orange rank disc pops at its row's arrival
/// + 120 (MOTION-SPEC §5.33). Open the brief goes to Brief detail.
///
/// Figma over the component: the frames ink every rank disc orange; the
/// kit keeps the orange disc for your row, which is what marks it.
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
    final podium = board.podium;
    String name(int i) => i < podium.length ? podium[i].entry.name : '';
    String amount(int i) {
      final kobo = i < podium.length ? podium[i].entry.amountKobo : null;
      return kobo == null ? '' : nairaShort(kobo);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(IqSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            board.eyebrow,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: IqText.smallStrong.copyWith(color: IqColors.fg2),
          ),
          const SizedBox(height: IqSpace.s3),
          Text(board.title, style: IqText.title.copyWith(color: IqColors.fg)),
          const SizedBox(height: IqSpace.s3),
          IqPodium(
            name1: name(0),
            amount1: amount(0),
            avatar1: leaderboardAvatar(name(0), 64),
            name2: name(1),
            amount2: amount(1),
            avatar2: leaderboardAvatar(name(1), 52),
            name3: name(2),
            amount3: amount(2),
            avatar3: leaderboardAvatar(name(2), 52),
          ),
          const SizedBox(height: IqSpace.s3 * 3),
          Stagger(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _items(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _items() => [
    for (final (i, row) in board.rows.indexed) ...[
      if (i > 0) const SizedBox(height: IqLeaderboardRow.gap),
      StaggerItem(index: i, child: _row(row, i)),
    ],
  ];

  Widget _row(BoardRow row, int index) => MergeSemantics(
    child: IqLeaderboardRow(
      rank: '${row.entry.rank}',
      name: row.entry.name,
      entry: row.entry.entry,
      amount: row.entry.amountKobo == null ? '' : naira(row.entry.amountKobo!),
      showAmount: row.entry.amountKobo != null,
      state: row.you
          ? IqLeaderboardRowState.you
          : IqLeaderboardRowState.standard,
      accentRank: true,
      rankDelay: row.you && index < Stagger.moving
          ? IqDurations.stagger * index + IqDurations.chain
          : null,
    ),
  );
}

const _people = {
  'Chinedu A.': IqAvatarPresets.person2,
  'Tunde F.': IqAvatarPresets.person3,
  'Ngozi E.': IqAvatarPresets.person4,
};

/// The sample people's avatars by name on the podium (B13, 548:25018);
/// anyone else, Anonymous too, is a tint disc (193:9779). The B13 frames
/// copy a person onto Anonymous; an anonymous entry shows no one's face.
Widget leaderboardAvatar(String name, double size) {
  final look = _people[name];
  if (look != null) return IqAvatar(IqPersonAvatar(look), size: size);
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: IqColors.tint,
      shape: BoxShape.circle,
    ),
  );
}
