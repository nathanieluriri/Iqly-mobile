import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// Exp/TextLink: a small text action (Filter, See all) on a 44 tall hit
/// area.
class IqTextLink extends StatelessWidget {
  const IqTextLink({
    super.key,
    this.label = 'Filter',
    this.icon = IqIcons.filter,
    this.showIcon = true,
    this.onTap,
  });

  final String label;
  final IqIcons icon;
  final bool showIcon;
  final VoidCallback? onTap;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      tactile: false,
      onTap: onTap,
      semanticLabel: label,
      builder: (context, pressed) => PressDim(
        pressed: pressed,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: IqSpace.s1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                IqIcon(icon, size: 16, color: IqColors.fg),
                const SizedBox(width: IqSpace.s1p5),
              ],
              Text(
                label,
                maxLines: 1,
                style: IqText.smallStrong.copyWith(color: IqColors.fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
