import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';

enum IqSwitchState { off, on }

/// Exp/Switch: a 52 x 32 toggle. On is the ink track, Off the line track;
/// the knob stays white. Tapping reports the flipped state through
/// [onChanged] with the select haptic; the knob travels 20 px and the fills
/// cross over in 160 ms ease-out, a cut under reduced motion. Pair with
/// Exp/SettingRow for the full-width 64 px target.
///
/// Figma over brief: both knobs carry a 1.5 px Color/brand outline.
/// Figma over its description: since the 5 Oct update the On knob is white,
/// not the orange marker, and the Off track is Color/line.
/// Figma gives no timing; 160 ms follows the kit rule of 150 to 300 ms ease-out.
class IqSwitch extends StatelessWidget {
  const IqSwitch({
    super.key,
    this.state = IqSwitchState.off,
    this.onChanged,
    this.semanticLabel,
  });

  final IqSwitchState state;
  final ValueChanged<IqSwitchState>? onChanged;

  /// Needed when the switch stands alone; Exp/SettingRow supplies its own.
  final String? semanticLabel;

  static const Duration duration = IqDurations.tick;

  @override
  Widget build(BuildContext context) {
    final on = state == IqSwitchState.on;
    final duration = motion(context, IqSwitch.duration);
    final onChanged = this.onChanged;
    return Semantics(
      toggled: on,
      enabled: onChanged != null,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null
            ? null
            : () {
                IqHaptics.select.play();
                onChanged(on ? IqSwitchState.off : IqSwitchState.on);
              },
        child: AnimatedContainer(
          duration: duration,
          curve: IqCurves.easeOut,
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(IqSpace.s1),
          decoration: BoxDecoration(
            color: on ? IqColors.brand : IqColors.line,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedAlign(
            duration: duration,
            curve: IqCurves.easeOut,
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: duration,
              curve: IqCurves.easeOut,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: IqColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: IqColors.brand, width: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
