import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'avatar.dart';
import 'pressable.dart';
import 'vector.dart';

/// Figma State=Default is [standard].
enum IqAvatarOptionTileState { standard, selected }

/// Exp/Avatar/OptionTile: one option for a part, shown on the person's own
/// avatar with that option applied (the nested Character, 120 at -10, -6,
/// on the tile's tint). [none] is the "no glasses, no headwear" choice: the
/// struck circle at 35% instead of the avatar. Selected adds a primary ring
/// and the check.
class IqAvatarOptionTile extends StatelessWidget {
  const IqAvatarOptionTile({
    super.key,
    this.look = const IqAvatarLook(),
    this.none = false,
    this.state = IqAvatarOptionTileState.standard,
    this.scales = const {},
    this.semanticLabel,
    this.onTap,
  });

  final IqAvatarLook look;
  final bool none;
  final IqAvatarOptionTileState state;

  /// Pops the changed part on the tile as it does on the preview.
  final Map<IqAvatarPart, double> scales;
  final String? semanticLabel;
  final VoidCallback? onTap;

  static const double size = 100;
  static const double radius = 22;
  static const double ring = 2.5;

  @override
  Widget build(BuildContext context) {
    final selected = state == IqAvatarOptionTileState.selected;
    final ink = motion(context, IqDurations.tick);
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
            duration: ink,
            curve: IqCurves.easeOut,
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: IqColors.tint,
              borderRadius: BorderRadius.circular(radius),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: selected
                    ? IqColors.primary
                    : IqColors.primary.withValues(alpha: 0),
                width: ring,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (none)
                  const Positioned(
                    left: 30,
                    top: 30,
                    child: Opacity(
                      opacity: 0.35,
                      child: IqVector(
                        'assets/vectors/avatar-option-tile-none.svg',
                        color: IqColors.brand,
                        width: 40,
                        height: 40,
                      ),
                    ),
                  )
                else
                  Positioned(
                    left: -10,
                    top: -6,
                    child: IqAvatarCharacter(
                      look: look,
                      size: 120,
                      showBackground: false,
                      scales: scales,
                    ),
                  ),
                Positioned(
                  left: 72,
                  top: 6,
                  child: AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: ink,
                    curve: IqCurves.easeOut,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: IqColors.primary,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.fromLTRB(5.3, 6.8, 0, 0),
                      alignment: Alignment.topLeft,
                      child: const IqVector(
                        'assets/vectors/avatar-option-tile-tick.svg',
                        color: IqColors.primaryFg,
                        width: 12,
                        height: 9,
                      ),
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
