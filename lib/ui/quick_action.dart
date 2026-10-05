import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqQuickActionKind { primary, standard }

/// Exp/QuickAction: a rectangular quick action under the wallet. One
/// Primary (Withdraw), the rest Default (Bank account, Filter). Figma
/// Kind=Default is [IqQuickActionKind.standard].
class IqQuickAction extends StatelessWidget {
  const IqQuickAction({
    super.key,
    this.kind = IqQuickActionKind.primary,
    this.label = 'Withdraw',
    this.icon = IqIcons.arrow,
    this.onTap,
  });

  final IqQuickActionKind kind;
  final String label;
  final IqIcons icon;
  final VoidCallback? onTap;

  static const Size size = Size(114, 68);

  @override
  Widget build(BuildContext context) {
    final primary = kind == IqQuickActionKind.primary;
    return IqPressable(
      onTap: onTap,
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
  }
}
