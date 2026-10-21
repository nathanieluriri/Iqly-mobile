import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'tablet_icon.dart';

/// Figma State=Default is [standard].
enum IqBizNavItemState { standard, active }

/// Exp/Biz/NavItem (1721:13790), as the settings sub-navigation draws it:
/// 44 tall, radius 10, the 18 icon and a 14 label; the open page is grey
/// with fg text. Give [icon] or [tabletIcon].
class IqBizNavItem extends StatelessWidget {
  const IqBizNavItem({
    super.key,
    required this.label,
    this.icon,
    this.tabletIcon,
    this.state = IqBizNavItemState.standard,
    this.onTap,
  }) : assert((icon == null) != (tabletIcon == null));

  final String label;
  final IqIcons? icon;
  final IqTabletIcons? tabletIcon;
  final IqBizNavItemState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = state == IqBizNavItemState.active;
    final color = on ? IqColors.primary : IqColors.brand;
    final tablet = tabletIcon;
    return Semantics(
      selected: on,
      child: IqPressable(
        onTap: onTap,
        tactile: false,
        semanticLabel: label,
        builder: (context, pressed) => Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: IqSpace.s3),
          decoration: BoxDecoration(
            color: on || pressed ? IqColors.secondary : null,
            borderRadius: BorderRadius.circular(IqRadius.lg),
          ),
          child: Row(
            children: [
              if (tablet != null)
                IqTabletIcon(tablet, size: 18, color: color)
              else
                IqIcon(icon!, size: 18, color: color),
              const SizedBox(width: IqSpace.s3),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqWebText.bodySmall.copyWith(
                    color: on ? IqColors.fg : IqColors.fg2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
