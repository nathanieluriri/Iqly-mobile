import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';

/// The sticker shadow: a filled copy of the pill offset 4,4 behind it.
/// While [pressed] the pill drops onto it (Figma draws the drop at 3,3) and
/// the shadow goes, 120 ms ease-out, back in 160 (spec 5.2 drop). When
/// [visible] turns on the shadow peels out from under the pill, 0,0 to 4,4
/// as it fades in over 200 ms, and tucks back in 120 ease-in when it turns
/// off (spec 2.5 peel). Reduced motion: nothing moves and the shadow shows
/// or goes at once. Primary buttons and the next button only; never chips,
/// tabs or cards.
class Sticker extends StatefulWidget {
  const Sticker({
    super.key,
    required this.child,
    required this.radius,
    this.color = IqColors.accent,
    this.pressed = false,
    this.visible = true,
  });

  final Widget child;
  final double radius;
  final Color color;
  final bool pressed;
  final bool visible;

  static const double offset = IqTravel.sticker;
  static const double pressOffset = IqTravel.pressDrop;

  @override
  State<Sticker> createState() => _StickerState();
}

class _StickerState extends State<Sticker> with TickerProviderStateMixin {
  late final AnimationController _drop = AnimationController(vsync: this);
  late final AnimationController _peel = AnimationController(
    vsync: this,
    value: widget.visible ? 1 : 0,
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _drop.value = 0;
      _peel.value = widget.visible ? 1 : 0;
    } else if (widget.pressed && _drop.isDismissed) {
      _drop.value = 1;
    }
  }

  @override
  void didUpdateWidget(Sticker old) {
    super.didUpdateWidget(old);
    if (widget.pressed != old.pressed && !_reduced) {
      _drop.animateTo(
        widget.pressed ? 1 : 0,
        duration: widget.pressed ? IqDurations.press : IqDurations.release,
        curve: IqCurves.easeOut,
      );
    }
    if (widget.visible != old.visible) {
      if (_reduced) {
        _peel.value = widget.visible ? 1 : 0;
      } else if (widget.visible) {
        _peel.animateTo(1, duration: IqDurations.swap, curve: IqCurves.easeOut);
      } else {
        _peel.animateBack(
          0,
          duration: IqDurations.press,
          curve: IqCurves.easeIn,
        );
      }
    }
  }

  @override
  void dispose() {
    _drop.dispose();
    _peel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shadow = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([_drop, _peel]),
      child: widget.child,
      builder: (context, child) {
        final shift = Sticker.offset * _peel.value;
        final drop = Sticker.pressOffset * _drop.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(shift, shift),
                child: Opacity(
                  opacity: _peel.value * (1 - _drop.value),
                  child: shadow,
                ),
              ),
            ),
            Transform.translate(offset: Offset(drop, drop), child: child),
          ],
        );
      },
    );
  }
}
