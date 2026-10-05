import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'step_mark.dart';

/// The pre-5 Oct Exp/StepMark, kept for the entry and onboarding screens
/// until their row PRs move to the bar [IqStepMark]. The Hinge-style step
/// marker. The current step is a 44 pt
/// ring around a brush [icon]; the other steps are 6 pt dots, done and
/// upcoming alike.
///
/// Figma over brief: every variant ships with the profile icon; the swap is a nested override, exposed here as [icon].
///
/// Motion (MOTION-SPEC 4.1, 5.11): a new step or icon morphs, 300 ms ease
/// in and out: the slot becoming current grows 6 to 44 as the old one
/// shrinks, so the mark stays 80 wide; the ring stroke comes in over the
/// last 60% of the growth and the dot fill leaves over the first 40%; the
/// old icon fades and shrinks to .6 in 120, the new one pops from .6 at
/// +80 over 200. [shuttle] runs the same morph across a push. [swingIcon]
/// swings the icon once at +200 (the notifications ask's bell, spec 6.9).
/// Reduced motion: the new step shows at once and nothing swings.
class IqStepMarkRing extends StatefulWidget {
  const IqStepMarkRing({
    super.key,
    this.step = IqStepMarkStep.oneOfThree,
    this.icon = IqIcons.profile,
    this.swingIcon = false,
  });

  final IqStepMarkStep step;
  final IqIcons icon;
  final bool swingIcon;

  static const double ring = 44;
  static const double dot = 6;

  /// The chrome hero's shuttle (spec 4.1): the morph from the leaving
  /// page's mark, [from], to the arriving page's, [to], as [progress] runs.
  static Widget shuttle(
    BuildContext context,
    Animation<double> progress,
    Widget from,
    Widget to,
  ) => AnimatedBuilder(
    animation: progress,
    builder: (context, _) => _Morph(
      from: from as IqStepMarkRing,
      to: to as IqStepMarkRing,
      t: progress.value,
    ),
  );

  @override
  State<IqStepMarkRing> createState() => _IqStepMarkState();
}

class _IqStepMarkState extends State<IqStepMarkRing>
    with TickerProviderStateMixin {
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: IqDurations.screen,
    value: 1,
  );
  late final AnimationController _swing = AnimationController(
    vsync: this,
    duration: IqMomentTiming.swingAt + IqMomentTiming.swing,
  );
  late IqStepMarkRing _from = widget;
  bool _swung = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.swingIcon &&
        !_swung &&
        !MediaQuery.disableAnimationsOf(context)) {
      _swung = true;
      _swing.forward();
    }
  }

  @override
  void didUpdateWidget(IqStepMarkRing old) {
    super.didUpdateWidget(old);
    if (old.step == widget.step && old.icon == widget.icon) return;
    if (MediaQuery.disableAnimationsOf(context) ||
        old.step.count != widget.step.count) {
      _morph.value = 1;
      return;
    }
    _from = old;
    _morph.forward(from: 0);
  }

  @override
  void dispose() {
    _morph.dispose();
    _swing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_morph, _swing]),
      builder: (context, _) => _Morph(
        from: _morph.isCompleted ? widget : _from,
        to: widget,
        t: _morph.value,
        swing: _swingAngle(),
      ),
    );
  }

  /// The bell's angle in radians: through the keyframes over 480 ms
  /// ease-out from +200.
  double _swingAngle() {
    if (!_swing.isAnimating) return 0;
    final total = _swing.duration!.inMicroseconds;
    final at = IqMomentTiming.swingAt.inMicroseconds / total;
    if (_swing.value <= at) return 0;
    final p = IqCurves.easeOut.transform((_swing.value - at) / (1 - at));
    const keys = IqAngles.bellSwing;
    final x = p * (keys.length - 1);
    final i = x.floor().clamp(0, keys.length - 2);
    final degrees = keys[i] + (keys[i + 1] - keys[i]) * (x - i);
    return degrees * math.pi / 180;
  }
}

/// The mark at [t] of the morph from [from] to [to]. The icon beats are
/// set for the 300 ms push and keep their share of a shorter back move.
class _Morph extends StatelessWidget {
  const _Morph({
    required this.from,
    required this.to,
    required this.t,
    this.swing = 0,
  });

  final IqStepMarkRing from;
  final IqStepMarkRing to;
  final double t;
  final double swing;

  double _at(Duration beat) =>
      beat.inMicroseconds / IqDurations.screen.inMicroseconds;

  @override
  Widget build(BuildContext context) {
    final step = to.step;
    final settled = t >= 1 || from.step.count != step.count;
    final g = IqCurves.easeInOut.transform(t.clamp(0.0, 1.0));
    final iconOut = settled
        ? 1.0
        : IqCurves.easeIn.transform(
            (t / _at(IqChromeTiming.iconOut)).clamp(0.0, 1.0),
          );
    final iconIn = settled
        ? 1.0
        : IqCurves.easeOut.transform(
            ((t - _at(IqChromeTiming.iconInAt)) / _at(IqChromeTiming.iconIn))
                .clamp(0.0, 1.0),
          );
    final iconChanges =
        !settled && (from.step.current != step.current || from.icon != to.icon);
    final children = <Widget>[];
    for (var i = 0; i < step.count; i++) {
      if (i > 0) children.add(const SizedBox(width: IqSpace.s3));
      final was = !settled && from.step.current == i;
      final isNow = step.current == i;
      final double size;
      final double ring;
      final double fill;
      if (settled || was == isNow) {
        size = isNow ? IqStepMarkRing.ring : IqStepMarkRing.dot;
        ring = isNow ? 1 : 0;
        fill = isNow ? 0 : 1;
      } else if (isNow) {
        size =
            IqStepMarkRing.dot + (IqStepMarkRing.ring - IqStepMarkRing.dot) * g;
        ring = ((g - 0.4) / 0.6).clamp(0.0, 1.0);
        fill = 1 - (g / 0.4).clamp(0.0, 1.0);
      } else {
        size =
            IqStepMarkRing.ring -
            (IqStepMarkRing.ring - IqStepMarkRing.dot) * g;
        ring = 1 - (g / 0.6).clamp(0.0, 1.0);
        fill = ((g - 0.6) / 0.4).clamp(0.0, 1.0);
      }
      final icons = <Widget>[
        if (was && iconChanges && iconOut < 1)
          _icon(
            from.icon,
            scale: 1 - (1 - IqScale.pop) * iconOut,
            opacity: 1 - iconOut,
          ),
        if (isNow)
          iconChanges
              ? _icon(
                  to.icon,
                  scale: IqScale.pop + (1 - IqScale.pop) * iconIn,
                  opacity: iconIn,
                )
              : _icon(to.icon, turn: swing),
      ];
      children.add(_slot(size, ring, fill, icons));
    }
    return Semantics(
      label: 'Step ${step.current + 1} of ${step.count}',
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _slot(double size, double ring, double fill, List<Widget> icons) {
    return SizedBox(
      width: size,
      height: IqStepMarkRing.ring,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (fill > 0)
            Opacity(
              opacity: fill,
              child: SizedBox.square(
                dimension: size,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: IqColors.line2,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          if (ring > 0)
            Opacity(
              opacity: ring,
              child: SizedBox.square(
                dimension: size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size / 2),
                    border: Border.all(color: IqColors.brand, width: 2),
                  ),
                ),
              ),
            ),
          ...icons,
        ],
      ),
    );
  }

  Widget _icon(
    IqIcons icon, {
    double scale = 1,
    double opacity = 1,
    double turn = 0,
  }) {
    Widget glyph = IqIcon(icon, size: 22, color: IqColors.brand);
    if (turn != 0) {
      glyph = Transform.rotate(
        angle: turn,
        alignment: Alignment.topCenter,
        child: glyph,
      );
    }
    if (scale != 1) glyph = Transform.scale(scale: scale, child: glyph);
    if (opacity < 1) glyph = Opacity(opacity: opacity, child: glyph);
    return OverflowBox(
      maxWidth: IqStepMarkRing.ring,
      maxHeight: IqStepMarkRing.ring,
      child: glyph,
    );
  }
}
