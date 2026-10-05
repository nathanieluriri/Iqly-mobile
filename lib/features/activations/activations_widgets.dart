import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../theme/theme.dart';
import '../../ui/highlight.dart';

/// The Mob/Mono fg3 label the activation frames put over each block.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: IqText.mono.copyWith(color: IqColors.fg3),
  );
}

/// The header frame of the activation screens: 8 above, the business as an
/// eyebrow (or [above] it, a stamp), the title in Mob/Title, 8 below.
class ActivationHeader extends StatelessWidget {
  const ActivationHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.above,
  });

  final String eyebrow;
  final String title;
  final Widget? above;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IqSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (above != null) ...[above!, const SizedBox(height: IqSpace.s2)],
          Eyebrow(eyebrow),
          const SizedBox(height: IqSpace.s2),
          Text(title, style: IqText.title.copyWith(color: IqColors.fg)),
        ],
      ),
    );
  }
}

/// The orange Highlight "Earn ₦1,500" beside "per completion". The offer
/// sets the words on the marker's foot ([alignEnd]); the step screens set
/// them level with its top, as their frames do.
class RewardLine extends StatelessWidget {
  const RewardLine({super.key, required this.earn, this.alignEnd = false});

  final String earn;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          IqHighlight(text: earn),
          const SizedBox(width: IqSpace.s2),
          Flexible(
            child: Text(
              'per completion',
              style: IqText.small.copyWith(color: IqColors.fg2),
            ),
          ),
        ],
      ),
    );
  }
}

/// The paper action bar at the foot of a screen: 12 above and below, the
/// actions 8 apart, full width.
class ActionBar extends StatelessWidget {
  const ActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: IqColors.bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: IqSpace.s4,
          vertical: IqSpace.s3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) const SizedBox(height: IqSpace.s2),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// Whether a page above hides the screen around [context]: its tickers are
/// off, or the page has just started to leave and still covers it whole
/// (the first frame of a pop, when the tickers are already back on).
bool covered(BuildContext context) {
  if (!TickerMode.valuesOf(context).enabled) return true;
  return ModalRoute.of(context)?.secondaryAnimation?.value == 1;
}

/// The Dissolve between the states of one screen (spec 3.4): the new state
/// fades in over the old, 300 ms ease-out (the old reads ease-in as it
/// goes), a 150 ms crossfade under reduced motion. While a page above
/// covers the screen the change is a cut, so the screen is already in its
/// new state when that page leaves (Send proof back to Your proof, whose
/// change lands as the proof page starts to pop). The old state takes no
/// taps and offers no heroes on its way out, so the new state's top bar
/// joins a push or pop from the frame it is built (spec 4.3). [fit]
/// passthrough lets the states size the space, top aligned.
class StateDissolve extends StatefulWidget {
  const StateDissolve({
    super.key,
    required this.child,
    this.fit = StackFit.expand,
  });

  /// Keyed by the state; a new key dissolves.
  final Widget child;
  final StackFit fit;

  @override
  State<StateDissolve> createState() => _StateDissolveState();
}

class _StateDissolveState extends State<StateDissolve>
    with SingleTickerProviderStateMixin {
  // Preserved: the platform's remove-animations setting would otherwise
  // cut the 150 ms crossfade to 5% of its length.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );
  late final Animation<double> _in = _fade.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  late final Animation<double> _out = ReverseAnimation(
    _fade.drive(CurveTween(curve: FlippedCurve(IqCurves.easeOut))),
  );
  Widget? _previous;

  @override
  void didUpdateWidget(StateDissolve old) {
    super.didUpdateWidget(old);
    if (old.child.key == widget.child.key) return;
    final length = motion(context, IqDurations.screen, fade: true);
    if (covered(context) || length == Duration.zero) {
      _previous = null;
      _fade.value = 1;
      return;
    }
    final previous = _previous = old.child;
    _fade
      ..duration = length
      ..forward(from: 0).whenCompleteOrCancel(() {
        if (mounted && _previous == previous) {
          setState(() => _previous = null);
        }
      });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previous = _previous;
    return Stack(
      alignment: Alignment.topCenter,
      fit: widget.fit,
      children: [
        if (previous != null)
          FadeTransition(
            key: previous.key,
            opacity: _out,
            child: HeroMode(
              enabled: false,
              child: IgnorePointer(child: previous),
            ),
          ),
        FadeTransition(
          key: widget.child.key,
          opacity: _in,
          child: HeroMode(
            child: IgnorePointer(ignoring: false, child: widget.child),
          ),
        ),
      ],
    );
  }
}

/// The Hero tag of an activation's recording, from its thumbnail to the
/// player.
String proofHeroTag(String activationId) => 'activation-proof-$activationId';

/// The recording's frame on ink. The demo has no video, so it draws the
/// Exp/VideoPreview phone silhouette (88 x 170 with its 48 x 6 bar in a
/// 200 tall thumbnail) scaled to the space it gets, which keeps it whole
/// while it flies from the thumbnail to the player. The live version shows
/// the first frame (video_player).
class ProofFrame extends StatelessWidget {
  const ProofFrame({super.key});

  static const double _thumbnail = 200;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: IqColors.brand,
      child: LayoutBuilder(
        builder: (context, box) {
          final s = box.maxHeight / _thumbnail;
          return Center(
            child: Container(
              width: 88 * s,
              height: 170 * s,
              alignment: Alignment.topCenter,
              padding: EdgeInsets.only(top: 25 * s),
              decoration: BoxDecoration(
                color: IqColors.sidebarAccent,
                borderRadius: BorderRadius.circular(12 * s),
              ),
              child: Container(
                width: 48 * s,
                height: 6 * s,
                decoration: BoxDecoration(
                  color: IqColors.sidebarFg.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3 * s),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
