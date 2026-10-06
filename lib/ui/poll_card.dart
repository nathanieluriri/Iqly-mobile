import 'package:flutter/material.dart';

import '../core/motion.dart';
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
/// the product yet, so the defaults are illustrative. [hint] overrides the
/// Open line (the B2 frames say "Pick one").
///
/// Turning Voted reveals the results in place (MOTION-SPEC §5.27, the Figma
/// Smart Animate 33:169 to 33:289): the options cross into their result
/// look over 300 ms, the bars fill from nothing over 600 ms ease-out with
/// the percentages counting alongside, and the vote line appears (220).
/// Reduced motion: the Voted card at once.
///
/// Figma over brief: a Closed state exists.
class IqPollCard extends StatefulWidget {
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
    this.hint,
    this.onVote,
  });

  final String question;
  final IqPollCardState state;
  final List<IqPollCardOption> options;
  final int votes;
  final String timeLeft;
  final int chosen;
  final int? selected;
  final String? hint;
  final ValueChanged<int>? onVote;

  @override
  State<IqPollCard> createState() => _IqPollCardState();
}

class _IqPollCardState extends State<IqPollCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: IqDurations.fill,
    value: 1,
  );
  late final Animation<double> _filled = _fill.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  bool _revealed = false;

  @override
  void didUpdateWidget(IqPollCard old) {
    super.didUpdateWidget(old);
    if (old.state != IqPollCardState.open ||
        widget.state == IqPollCardState.open ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _revealed = true;
    _fill.forward(from: 0);
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint = switch (widget.state) {
      IqPollCardState.open =>
        widget.hint ?? 'Pick one · results show after you vote',
      IqPollCardState.voted => 'You voted · ${widget.votes} votes',
      IqPollCardState.closed => 'Final · ${widget.votes} votes',
    };
    final hintLine = Text(
      hint,
      style: IqText.small.copyWith(color: IqColors.fg3),
    );
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
              widget.question,
              style: IqText.cardTitle.copyWith(color: IqColors.brand),
            ),
            const SizedBox(height: IqSpace.s3),
            _revealed
                ? Appear(key: ValueKey(widget.state), child: hintLine)
                : hintLine,
            const SizedBox(height: IqSpace.s3),
            AnimatedBuilder(
              animation: _filled,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.options.length; i++) ...[
                    if (i > 0) const SizedBox(height: IqSpace.s2),
                    IqPollOption(
                      label: widget.options[i].label,
                      share: widget.options[i].share * _filled.value,
                      width: box.maxWidth,
                      state: _optionState(i),
                      onTap: widget.onVote == null
                          ? null
                          : () => widget.onVote!(i),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: IqSpace.s3),
            Text(
              widget.state == IqPollCardState.closed
                  ? 'Closed'
                  : widget.timeLeft,
              style: IqText.small.copyWith(color: IqColors.fg3),
            ),
          ],
        ),
      ),
    );
  }

  IqPollOptionState _optionState(int i) => switch (widget.state) {
    IqPollCardState.open =>
      i == widget.selected
          ? IqPollOptionState.selected
          : IqPollOptionState.standard,
    IqPollCardState.voted =>
      i == widget.chosen ? IqPollOptionState.chosen : IqPollOptionState.result,
    IqPollCardState.closed => IqPollOptionState.result,
  };
}
