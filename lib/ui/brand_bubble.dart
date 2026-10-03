import 'package:flutter/material.dart';

import '../core/motion.dart';
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
/// Motion (spec 5.28, 5.24; build extension): the ring and avatar press to
/// .96 (120 ms, back in 160). Turning Done crossfades the ring to grey (200
/// ms), pops the count out (150 ms ease-in) and pops the check in (220 ms)
/// from +120. The count rolls when it changes. Colours and badges change at
/// once under reduced motion, with no press scale.
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
    with TickerProviderStateMixin {
  late final AnimationController _count = AnimationController(
    vsync: this,
    value: _fresh ? 1 : 0,
  );
  late final AnimationController _check = AnimationController(
    vsync: this,
    value: _fresh ? 0 : 1,
  );
  Duration _ring = Duration.zero;

  bool get _fresh => widget.state == IqBrandBubbleState.newPolls;

  @override
  void didUpdateWidget(IqBrandBubble old) {
    super.didUpdateWidget(old);
    if (old.state == widget.state) return;
    final reduced = MediaQuery.disableAnimationsOf(context);
    _ring = reduced ? Duration.zero : IqDurations.swap;
    if (reduced) {
      _count.value = _fresh ? 1 : 0;
      _check.value = _fresh ? 0 : 1;
    } else if (_fresh) {
      _check.animateBack(
        0,
        duration: IqDurations.crossfade,
        curve: IqCurves.easeIn,
      );
      _count.animateTo(
        1,
        duration: IqDurations.appear,
        curve: IqCurves.easeOut,
      );
    } else {
      _count.animateBack(
        0,
        duration: IqDurations.crossfade,
        curve: IqCurves.easeIn,
      );
      _check.value = 0;
      _check.animateTo(
        1,
        duration: IqDurations.chain + IqDurations.appear,
        curve: Interval(
          IqDurations.chain.inMicroseconds /
              (IqDurations.chain + IqDurations.appear).inMicroseconds,
          1,
          curve: IqCurves.easeOut,
        ),
      );
    }
  }

  @override
  void dispose() {
    _count.dispose();
    _check.dispose();
    super.dispose();
  }

  Widget _pop(AnimationController pop, Widget child) => AnimatedBuilder(
    animation: pop,
    child: child,
    builder: (context, child) => pop.value == 0
        ? const SizedBox.shrink()
        : Opacity(
            opacity: pop.value,
            child: Transform.scale(
              scale: IqScale.pop + (1 - IqScale.pop) * pop.value,
              child: child,
            ),
          ),
  );

  @override
  Widget build(BuildContext context) {
    final fresh = _fresh;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return IqPressable(
      onTap: widget.onTap,
      builder: (context, pressed) => SizedBox(
        width: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: pressed && !reduced ? IqScale.soft : 1,
              duration: pressed ? IqDurations.press : IqDurations.release,
              curve: IqCurves.easeOut,
              child: SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 2.3,
                      top: 1.5,
                      width: 65.88,
                      height: 66.36,
                      child: TweenAnimationBuilder<Color?>(
                        tween: ColorTween(
                          end: fresh ? IqColors.accent : IqColors.line2,
                        ),
                        duration: _ring,
                        curve: IqCurves.easeOut,
                        builder: (context, ring, _) => IqVector(
                          'assets/vectors/brand-bubble-loop.svg',
                          color: ring!,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: AnimatedContainer(
                        duration: _ring,
                        curve: IqCurves.easeOut,
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: fresh ? IqColors.accentSoft : IqColors.panel,
                          shape: BoxShape.circle,
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            widget.initial,
                            style: IqText.title.copyWith(
                              color: fresh
                                  ? IqColors.accentStrong
                                  : IqColors.fg3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 50,
                      top: -2,
                      child: _pop(
                        _count,
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 22,
                            minHeight: 22,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: IqSpace.s1p5,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: IqColors.brand,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: IqColors.bg, width: 2),
                          ),
                          child: RollingText(
                            widget.count,
                            style: IqText.label.copyWith(
                              color: IqColors.primaryFg,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 50,
                      top: -2,
                      child: _pop(
                        _check,
                        Container(
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
}
