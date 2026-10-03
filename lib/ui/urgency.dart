import 'package:flutter/material.dart';

import '../core/deadline.dart';
import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';

enum IqUrgencyTone {
  hot,
  warm,
  calm,
  closed;

  /// The deadlineLabel() ladder: Hot under 24 h, Warm under 7 days, Calm
  /// otherwise or with no deadline, Closed once the brief has closed.
  static IqUrgencyTone of(Duration? remaining, {bool closed = false}) {
    if (closed || (remaining != null && remaining <= Duration.zero)) {
      return IqUrgencyTone.closed;
    }
    if (remaining == null) return IqUrgencyTone.calm;
    if (remaining < DeadlineRules.urgencyHot) return IqUrgencyTone.hot;
    if (remaining < DeadlineRules.urgencyWarm) return IqUrgencyTone.warm;
    return IqUrgencyTone.calm;
  }
}

/// Exp/Urgency: the deadline chip, a clock and the brief's own deadline
/// words on a pill that hugs its text. New words roll their changed
/// characters (160 ms); a tone change crossfades the fill and ink once over
/// 400 ms. It never pulses: the Countdown is the clock that pulses (spec
/// 5.14). A cut under reduced motion.
///
/// Version B guidance (Figma 166:1011): the 400 ms tone change.
class IqUrgency extends StatelessWidget {
  const IqUrgency({
    super.key,
    this.text = 'Closes in 6h',
    this.tone = IqUrgencyTone.hot,
  });

  final String text;
  final IqUrgencyTone tone;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (tone) {
      IqUrgencyTone.hot => (IqColors.accent, IqColors.brand),
      IqUrgencyTone.warm => (IqColors.accentSoft, IqColors.brand),
      IqUrgencyTone.calm => (IqColors.panel, IqColors.fg2),
      IqUrgencyTone.closed => (IqColors.fg3, IqColors.primaryFg),
    };
    final duration = motion(context, IqDurations.tone);
    return AnimatedContainer(
      duration: duration,
      curve: IqCurves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(IqRadius.full),
      ),
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: ink),
        duration: duration,
        curve: IqCurves.easeOut,
        builder: (context, ink, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IqIcon(IqIcons.clock, size: 14, color: ink!),
            const SizedBox(width: 5),
            Flexible(
              child: RollingText(
                text,
                overflow: TextOverflow.ellipsis,
                style: IqText.smallStrong.copyWith(color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
