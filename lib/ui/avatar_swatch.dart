import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'pressable.dart';

/// Figma State=Default is [standard].
enum IqAvatarSwatchState { standard, selected }

/// Exp/Avatar/Swatch: a 38 colour disc from the Avatar collection in a 48
/// target. Selected adds a 2.5 primary ring inside the target.
class IqAvatarSwatch extends StatelessWidget {
  const IqAvatarSwatch({
    super.key,
    required this.colour,
    this.state = IqAvatarSwatchState.standard,
    this.semanticLabel,
    this.onTap,
  });

  final Color colour;
  final IqAvatarSwatchState state;
  final String? semanticLabel;
  final VoidCallback? onTap;

  static const double size = 48;
  static const double disc = 38;
  static const double ring = 2.5;

  @override
  Widget build(BuildContext context) {
    final selected = state == IqAvatarSwatchState.selected;
    return Semantics(
      selected: selected,
      button: true,
      child: IqPressable(
        onTap: onTap,
        semanticLabel: semanticLabel,
        haptic: IqHaptics.select,
        builder: (context, pressed) => PressDim(
          pressed: pressed,
          child: AnimatedContainer(
            duration: motion(context, IqDurations.tick),
            curve: IqCurves.easeOut,
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? IqColors.primary
                    : IqColors.primary.withValues(alpha: 0),
                width: ring,
              ),
            ),
            child: Container(
              width: disc,
              height: disc,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}
