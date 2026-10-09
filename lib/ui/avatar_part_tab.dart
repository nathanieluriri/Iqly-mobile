import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// Figma State=Default is [standard].
enum IqAvatarPartTabState { standard, selected }

/// Exp/Avatar/PartTab: one part of the avatar editor. Selected sits on a
/// tint pill; Default is the same brand ink at 45%. The editor draws its
/// eight tabs at 44 x 44 over the component's 56 x 48.
class IqAvatarPartTab extends StatelessWidget {
  const IqAvatarPartTab({
    super.key,
    this.icon = IqIcons.face,
    this.state = IqAvatarPartTabState.standard,
    this.width = 56,
    this.height = 48,
    this.semanticLabel,
    this.onTap,
  });

  final IqIcons icon;
  final IqAvatarPartTabState state;
  final double width;
  final double height;
  final String? semanticLabel;
  final VoidCallback? onTap;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final selected = state == IqAvatarPartTabState.selected;
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
            width: width,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? IqColors.tint
                  : IqColors.tint.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: AnimatedOpacity(
              duration: ink,
              curve: IqCurves.easeOut,
              opacity: selected ? 1 : 0.45,
              child: IqIcon(icon, size: 24, color: IqColors.brand),
            ),
          ),
        ),
      ),
    );
  }
}
