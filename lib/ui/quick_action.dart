import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqQuickActionKind { primary, standard }

/// Exp/QuickAction: a rectangular quick action under the wallet. One
/// Primary (Withdraw), the rest Default (Bank account, Filter). Figma
/// Kind=Default is [IqQuickActionKind.standard]. [disabled] is the empty
/// wallet's Withdraw (165:8921): the action at .4, not tappable.
class IqQuickAction extends StatelessWidget {
  const IqQuickAction({
    super.key,
    this.kind = IqQuickActionKind.primary,
    this.label = 'Withdraw',
    this.icon = IqIcons.arrow,
    this.onTap,
    this.disabled = false,
  });

  final IqQuickActionKind kind;
  final String label;
  final IqIcons icon;
  final VoidCallback? onTap;
  final bool disabled;

  static const Size size = Size(114, 68);
  static const double disabledOpacity = 0.4;

  @override
  Widget build(BuildContext context) {
    final primary = kind == IqQuickActionKind.primary;
    final action = IqPressable(
      onTap: onTap,
      enabled: !disabled,
      semanticLabel: label,
      builder: (context, pressed) => AnimatedContainer(
        duration: pressed ? IqDurations.dim : IqDurations.release,
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: primary
              ? (pressed ? IqColors.brandDark : IqColors.brand)
              : (pressed ? IqColors.panel : IqColors.card),
          borderRadius: BorderRadius.circular(IqRadius.xl),
          border: primary ? null : Border.all(color: IqColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IqIcon(
              icon,
              size: 22,
              color: primary ? IqColors.primaryFg : IqColors.brand,
            ),
            const SizedBox(height: IqSpace.s1p5),
            Text(
              label,
              maxLines: 1,
              style: IqText.smallStrong.copyWith(
                color: primary ? IqColors.primaryFg : IqColors.fg,
              ),
            ),
          ],
        ),
      ),
    );
    return disabled ? Opacity(opacity: disabledOpacity, child: action) : action;
  }
}
