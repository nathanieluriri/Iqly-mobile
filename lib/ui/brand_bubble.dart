import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/transitions.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'vector.dart';

enum IqBrandBubbleState { newPolls, done }

/// Exp/BrandBubble: one bubble per business with open polls, in story
/// grammar. The orange brush ring and [count] mean unanswered polls; the
/// grey ring and check mean all answered. [onTap] opens that business's
/// poll sheet. Figma State=New is [IqBrandBubbleState.newPolls].
///
/// Motion (spec 5.28, 5.24): the ring and avatar press to .96 (120 ms, back
/// in 160). Turning Done plays once: the ring and avatar cross to grey over
/// 200 ms, the count badge pops out (150 ms ease-in) and the check badge
/// pops in from +120 (220 ms). A new count rolls. A change that lands
/// while the bubble is hidden, or while a page stands over it or is still
/// on its way out (Discover as the Polls page pops), waits until it shows
/// with nothing over it, then plays once. Reduced motion: the new look at
/// once, with no press scale.
class IqBrandBubble extends StatefulWidget {
  const IqBrandBubble({
    super.key,
    this.initial = 'O',
    this.name = 'Orchid Foods',
    this.count = '2',
    this.state = IqBrandBubbleState.newPolls,
    this.onTap,
  });

  final String initial;
  final String name;
  final String count;
  final IqBrandBubbleState state;
  final VoidCallback? onTap;

  @override
  State<IqBrandBubble> createState() => _IqBrandBubbleState();
}

class _IqBrandBubbleState extends State<IqBrandBubble>
    with SingleTickerProviderStateMixin {
  static final _length = IqDurations.chain + IqDurations.appear;

  late final AnimationController _done = AnimationController(
    vsync: this,
    duration: _length,
    value: widget.state == IqBrandBubbleState.done ? 1 : 0,
  );
  late final Animation<double> _grey = _done.drive(
    CurveTween(curve: _span(Duration.zero, IqDurations.swap, IqCurves.easeOut)),
  );
  late final Animation<double> _countOut = _done.drive(
    CurveTween(
      curve: _span(Duration.zero, IqDurations.crossfade, IqCurves.easeIn),
    ),
  );
  late final Animation<double> _checkIn = _done.drive(
    CurveTween(
      curve: _span(IqDurations.chain, IqDurations.appear, IqCurves.easeOut),
    ),
  );
  late IqBrandBubbleState _shown = widget.state;
  late String _count = widget.count;
  bool _waiting = false;

  static Interval _span(Duration from, Duration length, Curve curve) {
    final total = _length.inMicroseconds;
    return Interval(
      from.inMicroseconds / total,
      (from + length).inMicroseconds / total,
      curve: curve,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _catchUp();
  }

  @override
  void didUpdateWidget(IqBrandBubble old) {
    super.didUpdateWidget(old);
    _catchUp();
  }

  void _catchUp() {
    final counting = widget.state == IqBrandBubbleState.newPolls;
    if (widget.state == _shown && (!counting || widget.count == _count)) {
      return;
    }
    if (_waiting || !TickerMode.valuesOf(context).enabled) return;
    _waiting = true;
    var now = true;
    whenUncovered(context, () {
      _waiting = false;
      if (now) {
        _show();
      } else if (mounted) {
        setState(_catchUp);
      }
    });
    now = false;
  }

  void _show() {
    if (widget.state == IqBrandBubbleState.newPolls) _count = widget.count;
    if (widget.state == _shown) return;
    _shown = widget.state;
    final done = _shown == IqBrandBubbleState.done;
    if (MediaQuery.disableAnimationsOf(context)) {
      _done.value = done ? 1 : 0;
    } else if (done) {
      _done.forward();
    } else {
      _done.reverse();
    }
  }

  @override
  void dispose() {
    _done.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: widget.onTap,
      builder: (context, pressed) => SizedBox(
        width: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: pressed && !MediaQuery.disableAnimationsOf(context)
                  ? IqScale.soft
                  : 1,
              duration: pressed ? IqDurations.press : IqDurations.release,
              curve: IqCurves.easeOut,
              child: SizedBox(
                width: 70,
                height: 70,
                child: AnimatedBuilder(
                  animation: _done,
                  builder: (context, _) => _ring(),
                ),
              ),
            ),
            const SizedBox(height: IqSpace.s1p5),
            Text(
              widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: IqText.small.copyWith(color: IqColors.fg2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring() {
    final grey = _grey.value;
    final countGone = _countOut.value;
    final checkIn = _checkIn.value;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 2.3,
          top: 1.5,
          width: 65.88,
          height: 66.36,
          child: IqVector(
            'assets/vectors/brand-bubble-loop.svg',
            color: Color.lerp(IqColors.accent, IqColors.line2, grey)!,
          ),
        ),
        Positioned(
          left: 8,
          top: 8,
          child: Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.lerp(IqColors.accentSoft, IqColors.panel, grey),
              shape: BoxShape.circle,
            ),
            child: ExcludeSemantics(
              child: Text(
                widget.initial,
                style: IqText.title.copyWith(
                  color: Color.lerp(IqColors.accentStrong, IqColors.fg3, grey),
                ),
              ),
            ),
          ),
        ),
        if (countGone < 1)
          Positioned(
            left: 50,
            top: -2,
            child: _badge(
              shown: 1 - countGone,
              child: Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: IqSpace.s1p5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: IqColors.brand,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: IqColors.bg, width: 2),
                ),
                child: RollingText(
                  _count,
                  style: IqText.label.copyWith(color: IqColors.primaryFg),
                ),
              ),
            ),
          ),
        if (checkIn > 0)
          Positioned(
            left: 50,
            top: -2,
            child: _badge(
              shown: checkIn,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: IqColors.okSoft,
                  shape: BoxShape.circle,
                ),
                child: const IqIcon(
                  IqIcons.check,
                  size: 14,
                  color: IqColors.ok,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// A badge [shown] from 0 (gone, at .6) to 1 (in place).
  Widget _badge({required double shown, required Widget child}) {
    if (shown >= 1) return child;
    return Opacity(
      opacity: shown,
      child: Transform.scale(
        scale: IqScale.pop + (1 - IqScale.pop) * shown,
        child: child,
      ),
    );
  }
}
