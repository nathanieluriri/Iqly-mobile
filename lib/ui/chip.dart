import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'pressable.dart';
import 'vector.dart';

/// Figma State=Default is [standard].
enum IqChipState { standard, selected }

/// Exp/Chip: a selectable 44 high pill for interests, occupations and feed
/// filters. Tapping reports the toggled state through [onChanged] with the
/// select haptic. Never a sticker shadow.
///
/// Figma over brief: Default is Color/card white, not the paper background.
/// Figma over brief: the Selected check is a plain 10 x 8 tick, not the brush check icon.
///
/// Motion (MOTION-SPEC 5.5, Figma 199:1306 "120 ms scale 0.96 to 1 on
/// select"): a press scales the chip to .96 and it springs back over 120 ms
/// ease-out; selecting crossfades the fill and label (120) while the tick's
/// 16 px slot opens and the tick pops from .6, so a Wrap's neighbours glide
/// with the width each frame; deselecting fades the tick as its slot closes
/// (120, ease-in). Reduced motion: colours and width cut, no scale.
class IqChip extends StatefulWidget {
  const IqChip({
    super.key,
    this.label = 'Marketing & advertising',
    this.state = IqChipState.standard,
    this.onChanged,
  });

  final String label;
  final IqChipState state;
  final ValueChanged<IqChipState>? onChanged;

  static const double height = 44;
  static const Duration pop = IqDurations.press;

  @override
  State<IqChip> createState() => _IqChipState();
}

class _IqChipState extends State<IqChip> with SingleTickerProviderStateMixin {
  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: IqChip.pop,
    value: _selected ? 1 : 0,
  );
  late final Animation<double> _tickPop = _tick.drive(
    Tween<double>(begin: IqScale.pop, end: 1),
  );

  bool get _selected => widget.state == IqChipState.selected;

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(IqChip old) {
    super.didUpdateWidget(old);
    if (widget.state == old.state) return;
    if (_reduced) {
      _tick.value = _selected ? 1 : 0;
      return;
    }
    _tick.animateTo(
      _selected ? 1 : 0,
      curve: _selected ? IqCurves.easeOut : IqCurves.easeIn,
    );
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final onChanged = widget.onChanged;
    final ink = motion(context, IqChip.pop);
    final curve = selected ? IqCurves.easeOut : IqCurves.easeIn;
    return Semantics(
      selected: selected,
      child: IqPressable(
        semanticLabel: widget.label,
        haptic: IqHaptics.select,
        onTap: onChanged == null
            ? null
            : () => onChanged(
                selected ? IqChipState.standard : IqChipState.selected,
              ),
        builder: (context, pressed) {
          return AnimatedScale(
            scale: pressed && !_reduced ? IqScale.chipPress : 1,
            duration: IqChip.pop,
            curve: IqCurves.easeOut,
            child: AnimatedContainer(
              duration: ink,
              curve: curve,
              height: IqChip.height,
              padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
              decoration: BoxDecoration(
                color: selected ? IqColors.brand : IqColors.card,
                borderRadius: BorderRadius.circular(IqChip.height / 2),
              ),
              // A foreground border keeps Figma's inside stroke out of the hug width.
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(IqChip.height / 2),
                border: Border.all(color: IqColors.brand, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The slot opens without clipping, so the tick's stroke
                  // bleed still shows once it is in.
                  AnimatedBuilder(
                    animation: _tick,
                    builder: (context, child) => Align(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: _tick.value,
                      child: child,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FadeTransition(
                          opacity: _tick,
                          child: ScaleTransition(
                            scale: _tickPop,
                            // The export carries 1 px of stroke bleed around the 10 x 8 tick.
                            child: const SizedBox(
                              width: 10,
                              height: 8,
                              child: OverflowBox(
                                maxWidth: 12,
                                maxHeight: 10,
                                child: IqVector(
                                  'assets/vectors/chip-check.svg',
                                  color: IqColors.primaryFg,
                                  width: 12,
                                  height: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: IqSpace.s1p5),
                      ],
                    ),
                  ),
                  Flexible(
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        end: selected ? IqColors.primaryFg : IqColors.fg,
                      ),
                      duration: ink,
                      curve: curve,
                      builder: (context, color, _) => Text(
                        widget.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: IqText.bodyStrong.copyWith(
                          color: color ?? IqColors.fg,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
