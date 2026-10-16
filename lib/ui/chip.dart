import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'pressable.dart';

/// Figma State=Default is [standard].
enum IqChipState { standard, selected }

/// Exp/Chip: a selectable 44 high pill for interests, occupations and feed
/// filters. Tapping reports the toggled state through [onChanged] with the
/// select haptic. Never a sticker shadow.
///
/// Figma over brief: since the 5 Oct update Default is a white pill with a
/// 1 pt line outline and Selected is a tint pill with a 1.5 pt brand outline
/// and brand label; the check is a hidden layer, so no tick shows.
///
/// Motion (MOTION-SPEC 5.5, Figma 199:1306 "120 ms scale 0.96 to 1 on
/// select"): a press scales the chip to .96 and it springs back over 120 ms
/// ease-out; selecting crossfades the fill, outline and label over 120 ms.
/// The width never changes. A change made while the chip is hidden (its page
/// covered) is in place when it shows again. Reduced motion: colours cut,
/// no scale.
///
/// [refused] is the peak of a refused pick (Row note 1284:90609, frame
/// 1284:90206): the outline and label take the error tones on the white
/// pill and ease back when it clears. [haptic] is the select tick unless the caller answers
/// the tap with its own.
class IqChip extends StatelessWidget {
  const IqChip({
    super.key,
    this.label = 'Marketing & advertising',
    this.state = IqChipState.standard,
    this.onChanged,
    this.refused = false,
    this.haptic = IqHaptics.select,
  });

  final String label;
  final IqChipState state;
  final ValueChanged<IqChipState>? onChanged;
  final bool refused;
  final IqHaptics? haptic;

  static const double height = 44;
  static const Duration pop = IqDurations.press;

  @override
  Widget build(BuildContext context) {
    final selected = state == IqChipState.selected;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final hidden = !TickerMode.valuesOf(context).enabled;
    final ink = hidden ? Duration.zero : motion(context, pop);
    final curve = selected ? IqCurves.easeOut : IqCurves.easeIn;
    final shape = BorderRadius.circular(height / 2);
    return Semantics(
      selected: selected,
      child: IqPressable(
        tactile: false,
        semanticLabel: label,
        haptic: haptic,
        onTap: onChanged == null
            ? null
            : () => onChanged!(
                selected ? IqChipState.standard : IqChipState.selected,
              ),
        builder: (context, pressed) {
          return AnimatedScale(
            scale: pressed && !reduced ? IqScale.chipPress : 1,
            duration: pop,
            curve: IqCurves.easeOut,
            child: AnimatedContainer(
              duration: ink,
              curve: curve,
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
              decoration: BoxDecoration(
                color: selected && !refused ? IqColors.tint : IqColors.card,
                borderRadius: shape,
              ),
              // A foreground border keeps Figma's inside stroke out of the hug width.
              foregroundDecoration: BoxDecoration(
                borderRadius: shape,
                border: refused
                    ? Border.all(color: IqColors.err, width: 1.5)
                    : selected
                    ? Border.all(color: IqColors.brand, width: 1.5)
                    : Border.all(color: IqColors.line),
              ),
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(
                  end: refused
                      ? IqColors.errStrong
                      : selected
                      ? IqColors.brand
                      : IqColors.fg,
                ),
                duration: ink,
                curve: curve,
                builder: (context, color, _) => Align(
                  widthFactor: 1,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: IqText.bodyStrong.copyWith(
                      color: color ?? IqColors.fg,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
