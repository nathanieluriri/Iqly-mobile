import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'tablet_icon.dart';

enum IqTabletNavItemLayout { rail, sidebar }

/// Figma State=Default is [standard].
enum IqTabletNavItemState { standard, selected }

/// Exp/Tablet/NavItem (local, sync to DS; 1807:34416). Rail: a 56 by 32
/// indicator over a 12 label in an 80 by 64 cell. Sidebar: a 216 by 48 row,
/// radius 10, the 24 icon and a 14 label. Selected is the grey indicator
/// with the primary icon and an fg label; there is no hover (tablet spec,
/// Shell). Give [icon] or [tabletIcon].
class IqTabletNavItem extends StatelessWidget {
  const IqTabletNavItem({
    super.key,
    required this.label,
    this.icon,
    this.tabletIcon,
    this.layout = IqTabletNavItemLayout.rail,
    this.state = IqTabletNavItemState.standard,
    this.showLabel = true,
    this.onTap,
  }) : assert((icon == null) != (tabletIcon == null));

  final String label;
  final IqIcons? icon;
  final IqTabletIcons? tabletIcon;
  final IqTabletNavItemLayout layout;
  final IqTabletNavItemState state;
  final bool showLabel;
  final VoidCallback? onTap;

  static const Size railSize = Size(80, 64);
  static const double sidebarWidth = 216;
  static const double sidebarHeight = 48;

  bool get _selected => state == IqTabletNavItemState.selected;

  Widget _icon() {
    final color = _selected
        ? IqColors.primary
        : tabletIcon != null
        ? IqColors.fg
        : IqColors.brand;
    final tablet = tabletIcon;
    return tablet != null
        ? IqTabletIcon(tablet, size: 24, color: color)
        : IqIcon(icon!, size: 24, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = _selected ? IqColors.fg : IqColors.fg2;
    return Semantics(
      button: true,
      selected: _selected,
      label: label,
      excludeSemantics: true,
      child: IqPressable(
        onTap: onTap,
        hint: showLabel ? null : label,
        builder: (context, pressed) => switch (layout) {
          IqTabletNavItemLayout.rail => SizedBox(
            width: railSize.width,
            height: railSize.height,
            child: Padding(
              padding: const EdgeInsets.only(
                top: IqSpace.s1,
                bottom: IqSpace.s2,
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _selected || pressed ? IqColors.secondary : null,
                      borderRadius: BorderRadius.circular(IqRadius.full),
                    ),
                    child: _icon(),
                  ),
                  if (showLabel) ...[
                    const SizedBox(height: IqSpace.s1),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      style: IqWebText.labelBadge.copyWith(color: labelColor),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IqTabletNavItemLayout.sidebar => Container(
            width: sidebarWidth,
            height: sidebarHeight,
            padding: const EdgeInsets.symmetric(horizontal: IqSpace.s3),
            decoration: BoxDecoration(
              color: _selected || pressed ? IqColors.secondary : null,
              borderRadius: BorderRadius.circular(IqRadius.lg),
            ),
            child: Row(
              children: [
                _icon(),
                const SizedBox(width: IqSpace.s3),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IqWebText.bodySmallStrong.copyWith(
                      color: labelColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        },
      ),
    );
  }
}
