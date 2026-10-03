import 'package:flutter/material.dart';

import '../theme/theme.dart';

enum IqSwitchState { off, on }

/// Exp/Switch: a 52 x 32 toggle. On is the ink track with the orange marker
/// knob (a state, not a warning). Tapping reports the flipped state through
/// [onChanged]; the knob travels 20 px and the fills cross over in 160 ms
/// ease-out, a cut under reduced motion. Pair with Exp/SettingRow for the
/// full-width 64 px target.
///
/// Figma over brief: both knobs carry a 1.5 px Color/brand outline.
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

  static const Duration duration = Duration(milliseconds: 160);

  @override
  Widget build(BuildContext context) {
    final on = state == IqSwitchState.on;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : IqSwitch.duration;
    final onChanged = this.onChanged;
    return Semantics(
      toggled: on,
      enabled: onChanged != null,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null
            ? null
            : () => onChanged(on ? IqSwitchState.off : IqSwitchState.on),
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(IqSpace.s1),
          decoration: BoxDecoration(
            color: on ? IqColors.brand : IqColors.line2,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedAlign(
            duration: duration,
            curve: Curves.easeOut,
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: on ? IqColors.accent : IqColors.card,
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
