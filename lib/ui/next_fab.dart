import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'sticker.dart';

enum IqNextFabState { disabled, enabled }

/// Exp/NextFab: the round next button for one-question screens, disabled
/// until the field is valid. Enabled is the ink disc with the white brush
/// chevron on the orange sticker; press drops the disc onto it (120 ms)
/// with the commit haptic, and turning enabled peels the sticker out.
class IqNextFab extends StatelessWidget {
  const IqNextFab({
    super.key,
    this.state = IqNextFabState.disabled,
    this.onTap,
    this.semanticLabel = 'Next',
  });

  final IqNextFabState state;
  final VoidCallback? onTap;
  final String semanticLabel;

  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final enabled = state == IqNextFabState.enabled;
    return IqPressable(
      onTap: onTap,
      enabled: enabled,
      semanticLabel: semanticLabel,
      haptic: IqHaptics.commit,
      builder: (context, pressed) => SizedBox.square(
        dimension: size,
        child: Sticker(
          radius: size / 2,
          visible: enabled,
          pressed: pressed,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled ? IqColors.brand : IqColors.line,
              shape: BoxShape.circle,
            ),
            child: IqIcon(
              IqIcons.forward,
              size: 24,
              color: enabled ? IqColors.card : IqColors.fg3,
            ),
          ),
        ),
      ),
    );
  }
}
