import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'vector.dart';

enum IqPollOptionState { standard, selected, result, chosen }

/// Exp/PollOption: one answer on a poll. Before voting it is a brush outline
/// pill ([onTap] picks it, with the select haptic); Selected is filled ink
/// with a check. Result and Chosen show the share bar, whose fill stops at
/// [share] (0 to 1) with the Figma 2.4 point soft edge, and the rounded
/// percentage. Figma State=Default is [IqPollOptionState.standard].
///
/// A new state moves in its parts (MOTION-SPEC §5.27): the ground crosses
/// over, 120 ms for a pick (ink fills in) and 300 for the result looks, the
/// Smart Animate of the B2 frames; the check pops (220) as its slot opens and
/// eases the label right; the label's ink and weight ease across; the
/// percentage fades in. A first build shows its state still. Under reduced
/// motion the parts cut and the check fades in 150, as a pop does.
class IqPollOption extends StatelessWidget {
  const IqPollOption({
    super.key,
    this.label = 'Zobo and ginger',
    this.state = IqPollOptionState.standard,
    this.share = 0.45,
    this.onTap,
    this.width = 326,
  });

  final String label;
  final IqPollOptionState state;
  final double share;
  final VoidCallback? onTap;

  /// 326 in the master; Exp/PollCard fills its 324 column.
  final double width;
  static const double height = 52;

  /// The check and its gap before the label.
  static const double _checkSlot = 18 + IqSpace.s2p5;

  bool get _voting =>
      state == IqPollOptionState.standard ||
      state == IqPollOptionState.selected;

  bool get _marked =>
      state == IqPollOptionState.selected || state == IqPollOptionState.chosen;

  @override
  Widget build(BuildContext context) {
    final change = motion(
      context,
      _voting ? IqDurations.press : IqDurations.screen,
    );
    final ink = switch (state) {
      IqPollOptionState.standard ||
      IqPollOptionState.result => IqText.body.copyWith(color: IqColors.fg),
      IqPollOptionState.selected => IqText.bodyStrong.copyWith(
        color: IqColors.primaryFg,
      ),
      IqPollOptionState.chosen => IqText.bodyStrong.copyWith(
        color: IqColors.fg,
      ),
    };
    return IqPressable(
      onTap: _voting ? onTap : null,
      haptic: IqHaptics.select,
      builder: (context, _) => SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: change,
                switchInCurve: IqCurves.easeOut,
                switchOutCurve: IqCurves.easeOut,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, ?current],
                ),
                child: Stack(key: ValueKey(state), children: _ground()),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: change,
                      curve: IqCurves.easeOut,
                      width: _marked ? _checkSlot : 0,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: _checkSlot,
                          maxWidth: _checkSlot,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _check(context, change),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: change,
                        curve: IqCurves.easeOut,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DefaultTextStyle.of(context).style.merge(ink),
                        child: Text(label),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: change,
                      switchInCurve: IqCurves.easeOut,
                      switchOutCurve: IqCurves.easeOut,
                      child: _voting
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(
                                left: IqSpace.s2p5,
                              ),
                              child: Text(
                                '${(share * 100).round()}%',
                                style: IqText.figureSmall.copyWith(
                                  color: state == IqPollOptionState.chosen
                                      ? IqColors.brand
                                      : IqColors.fg2,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _check(BuildContext context, Duration change) {
    return AnimatedSwitcher(
      duration: motion(context, IqDurations.appear, fade: true),
      switchInCurve: IqCurves.easeOut,
      switchOutCurve: IqCurves.easeOut,
      transitionBuilder: MediaQuery.disableAnimationsOf(context)
          ? AnimatedSwitcher.defaultTransitionBuilder
          : _pop,
      child: _marked
          ? TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: state == IqPollOptionState.selected
                    ? IqColors.primaryFg
                    : IqColors.brand,
              ),
              duration: change,
              curve: IqCurves.easeOut,
              builder: (context, ink, _) =>
                  IqIcon(IqIcons.check, size: 18, color: ink!),
            )
          : const SizedBox.shrink(),
    );
  }

  static Widget _pop(Widget child, Animation<double> progress) =>
      FadeTransition(
        opacity: progress,
        child: ScaleTransition(
          scale: progress.drive(Tween(begin: IqScale.pop, end: 1)),
          child: child,
        ),
      );

  List<Widget> _ground() {
    switch (state) {
      case IqPollOptionState.standard:
        return [
          _outline('assets/vectors/poll-option-outline.svg', IqColors.brand),
        ];
      case IqPollOptionState.selected:
        return [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: IqColors.brand,
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
        ];
      case IqPollOptionState.result:
        return [
          _share(IqColors.panel),
          Positioned(
            left: 0,
            top: 0,
            width: 324.02,
            height: 51.26,
            child: IqVector(
              'assets/vectors/poll-option-outline-result.svg',
              color: IqColors.line2,
            ),
          ),
        ];
      case IqPollOptionState.chosen:
        return [
          _share(IqColors.accentSoft),
          _outline('assets/vectors/poll-option-outline.svg', IqColors.brand),
        ];
    }
  }

  Widget _outline(String asset, Color color) => Positioned(
    left: 0,
    top: 0,
    width: 324.32,
    height: 51.82,
    child: IqVector(asset, color: color),
  );

  Widget _share(Color color) {
    final s = share.clamp(0.0, 1.0);
    final from = (s - 0.012).clamp(0.0, 1.0);
    final to = (s + 0.012).clamp(0.0, 1.0);
    return Positioned(
      left: 4,
      top: 6,
      width: 318,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              color,
              color,
              color.withValues(alpha: 0),
              color.withValues(alpha: 0),
            ],
            stops: [0, from, to, 1],
          ),
        ),
      ),
    );
  }
}
