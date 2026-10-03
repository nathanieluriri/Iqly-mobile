import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'pressable.dart';
import 'vector.dart';

/// Figma State=Default is [standard].
enum IqChipState { standard, selected }

/// Exp/Chip: a selectable 44 high pill for interests, occupations and feed
/// filters. Tapping reports the toggled state through [onChanged] with the
/// select haptic; turning Selected pops the chip from 0.96 to 1 over 120 ms
/// (no motion under reduced motion). Never a sticker shadow.
///
/// Figma over brief: Default is Color/card white, not the paper background.
/// Figma over brief: the Selected check is a plain 10 x 8 tick, not the brush check icon.
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
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: IqChip.pop,
    value: 1,
  );
  late final Animation<double> _scale = _pop.drive(
    Tween<double>(
      begin: IqScale.chipPress,
      end: 1,
    ).chain(CurveTween(curve: IqCurves.easeOut)),
  );

  @override
  void didUpdateWidget(IqChip old) {
    super.didUpdateWidget(old);
    if (widget.state == IqChipState.selected &&
        old.state != IqChipState.selected &&
        !MediaQuery.disableAnimationsOf(context)) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.state == IqChipState.selected;
    final onChanged = widget.onChanged;
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
        builder: (context, pressed) => ScaleTransition(
          scale: _scale,
          child: Container(
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
                if (selected) ...[
                  // The export carries 1 px of stroke bleed around the 10 x 8 tick.
                  const SizedBox(
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
                  const SizedBox(width: IqSpace.s1p5),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: IqText.bodyStrong.copyWith(
                      color: selected ? IqColors.primaryFg : IqColors.fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
