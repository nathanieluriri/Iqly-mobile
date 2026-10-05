import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'vector.dart';

/// Figma Shine=1, 2 and 3: the three twinkle keyframes.
enum IqGiftButtonShine {
  one(0.3, Offset(-6.25, -2.63)),
  two(1, Offset(-10.25, -6.1)),
  three(0.7, Offset(-3.5, -7.25));

  const IqGiftButtonShine(this.opacity, this.offset);

  final double opacity;

  /// Where the rays' bounds sit against the 44 button.
  final Offset offset;

  String layer(String ink) =>
      'assets/vectors/gift-button-shine-${index + 1}-$ink.svg';
}

/// Exp/GiftButton: the referral entry in the top bar. The rays twinkle on
/// a loop (Shine 1, 2, 3); tapping opens Referrals.
///
/// Motion (designer answer 32): [twinkle] runs the loop once per session,
/// on the first Discover load, 0.8 s after it settles. The screen decides
/// when; a still button shows [shine]. Reduced motion holds Shine 2.
class IqGiftButton extends StatefulWidget {
  const IqGiftButton({
    super.key,
    this.shine = IqGiftButtonShine.two,
    this.twinkle = false,
    this.onTap,
  });

  final IqGiftButtonShine shine;
  final bool twinkle;
  final VoidCallback? onTap;

  static const double size = 44;
  static const Duration loop = Duration(milliseconds: 1200);

  @override
  State<IqGiftButton> createState() => _IqGiftButtonState();
}

class _IqGiftButtonState extends State<IqGiftButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: IqGiftButton.loop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(IqGiftButton old) {
    super.didUpdateWidget(old);
    if (old.twinkle != widget.twinkle) _sync();
  }

  void _sync() {
    if (widget.twinkle && !MediaQuery.disableAnimationsOf(context)) {
      if (!_loop.isAnimating) _loop.forward(from: 0);
    } else {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  IqGiftButtonShine get _frame {
    if (!_loop.isAnimating) return widget.shine;
    final t = _loop.value;
    return t < 1 / 3
        ? IqGiftButtonShine.one
        : t < 2 / 3
        ? IqGiftButtonShine.two
        : IqGiftButtonShine.three;
  }

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: widget.onTap,
      semanticLabel: 'Invite friends',
      builder: (context, pressed) => AnimatedBuilder(
        animation: _loop,
        builder: (context, _) {
          final frame = _frame;
          return SizedBox.square(
            dimension: IqGiftButton.size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: pressed ? IqDurations.dim : IqDurations.release,
                    decoration: BoxDecoration(
                      color: pressed ? IqColors.panel : IqColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: IqColors.line),
                    ),
                  ),
                ),
                Positioned(
                  left: frame.offset.dx,
                  top: frame.offset.dy,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: frame.opacity,
                      child: Stack(
                        children: [
                          IqVector(
                            frame.layer('accent'),
                            color: IqColors.accentStrong,
                          ),
                          IqVector(
                            frame.layer('tint'),
                            color: IqColors.tintStrong,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Center(
                  child: IqIcon(IqIcons.gift, size: 22, color: IqColors.brand),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
