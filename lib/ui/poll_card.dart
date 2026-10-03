import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'poll_option.dart';

enum IqPollCardState { open, voted, closed }

class IqPollCardOption {
  const IqPollCardOption(this.label, this.share);

  final String label;

  /// Votes over total, 0 to 1; shown rounded.
  final double share;
}

/// Exp/PollCard: a poll answered in place. Results stay hidden until you
/// vote so the crowd does not sway the answer. Open takes a tap per option
/// ([onVote] with its index; [selected] shows the picked one); Voted marks
/// [chosen]; Closed shows the final shares. Poll data does not exist in
/// the product yet, so the defaults are illustrative.
///
/// Figma over brief: a Closed state exists.
class IqPollCard extends StatelessWidget {
  const IqPollCard({
    super.key,
    this.question = 'Which flavour should we launch first?',
    this.state = IqPollCardState.open,
    this.options = const [
      IqPollCardOption('Zobo and ginger', 0.45),
      IqPollCardOption('Tiger nut', 0.33),
      IqPollCardOption('Pineapple and mint', 0.22),
    ],
    this.votes = 214,
    this.timeLeft = '2 days left',
    this.chosen = 0,
    this.selected,
    this.onVote,
  });

  final String question;
  final IqPollCardState state;
  final List<IqPollCardOption> options;
  final int votes;
  final String timeLeft;
  final int chosen;
  final int? selected;
  final ValueChanged<int>? onVote;

  @override
  Widget build(BuildContext context) {
    final hint = switch (state) {
      IqPollCardState.open => 'Pick one · results show after you vote',
      IqPollCardState.voted => 'You voted · $votes votes',
      IqPollCardState.closed => 'Final · $votes votes',
    };
    return Container(
      padding: const EdgeInsets.all(IqSpace.s4),
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: IqColors.line),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              question,
              style: IqText.cardTitle.copyWith(color: IqColors.brand),
            ),
            const SizedBox(height: IqSpace.s3),
            Text(hint, style: IqText.small.copyWith(color: IqColors.fg3)),
            const SizedBox(height: IqSpace.s3),
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(height: IqSpace.s2),
              IqPollOption(
                label: options[i].label,
                share: options[i].share,
                width: box.maxWidth,
                state: _optionState(i),
                onTap: onVote == null ? null : () => onVote!(i),
              ),
            ],
            const SizedBox(height: IqSpace.s3),
            Text(
              state == IqPollCardState.closed ? 'Closed' : timeLeft,
              style: IqText.small.copyWith(color: IqColors.fg3),
            ),
          ],
        ),
      ),
    );
  }

  IqPollOptionState _optionState(int i) => switch (state) {
    IqPollCardState.open =>
      i == selected ? IqPollOptionState.selected : IqPollOptionState.standard,
    IqPollCardState.voted =>
      i == chosen ? IqPollOptionState.chosen : IqPollOptionState.result,
    IqPollCardState.closed => IqPollOptionState.result,
  };
}
