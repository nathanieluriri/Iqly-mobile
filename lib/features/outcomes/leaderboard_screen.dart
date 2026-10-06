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
import '../../ui/sample_avatar.dart';
import '../../ui/top_bar.dart';
import '../submissions/brief_art.dart';
import '../submissions/submissions_routes.dart';
import 'outcomes_state.dart';
import 'result_screen.dart';

/// B13 · Leaderboard (193:9779) and Leaderboard · not selected (225:10747):
/// the brief, "Top 5 of 48 submissions", the podium, the other paid places
/// and, when you were not paid, the pool and your row. The rows arrive 40 apart,
/// the cutoff line draws in on its turn and the contributor's orange rank
/// disc pops at its row's arrival + 120 (MOTION-SPEC §5.33). Open the brief
/// goes to Brief detail.
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

  static const _people = {
    'Chinedu A.': IqSampleAvatarPerson.person1,
    'Tunde F.': IqSampleAvatarPerson.person2,
    'Ngozi E.': IqSampleAvatarPerson.person3,
  };

  /// Sample portraits by name; Anonymous is a tint disc (193:9779).
  static Widget _avatar(String name, double size) {
    final person = _people[name];
    if (person != null) return IqSampleAvatar(person: person, size: size);
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: IqColors.tint,
        shape: BoxShape.circle,
      ),
    );
  }

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
            avatar1: _avatar(name(0), 64),
            name2: name(1),
            amount2: amount(1),
            avatar2: _avatar(name(1), 52),
            name3: name(2),
            amount3: amount(2),
            avatar3: _avatar(name(2), 52),
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

  List<Widget> _items() {
    var slot = 0;
    return [
      for (final (i, item) in board.items.indexed) ...[
        if (i > 0) const SizedBox(height: IqLeaderboardRow.gap),
        if (item is BoardCutoff)
          _item(item, slot)
        else
          StaggerItem(index: slot, child: _item(item, slot++)),
      ],
    ];
  }

  Widget _item(BoardItem item, int index) => switch (item) {
    BoardRow(:final entry, :final you) => MergeSemantics(
      child: IqLeaderboardRow(
        rank: '${entry.rank}',
        name: entry.name,
        entry: entry.entry,
        amount: entry.amountKobo == null ? '' : naira(entry.amountKobo!),
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
            textAlign: TextAlign.center,
            style: IqText.small.copyWith(color: IqColors.fg2),
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
            style: IqText.small.copyWith(color: IqColors.fg2),
          ),
        ),
      ),
    ),
  };
}
