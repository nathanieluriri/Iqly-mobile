import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'tablet_icon.dart';

class IqWebAccountMenuItem {
  const IqWebAccountMenuItem({
    required this.label,
    this.icon,
    this.tabletIcon,
    this.trail,
    this.dividerBefore = false,
    this.onTap,
  });

  final String label;
  final IqIcons? icon;
  final IqTabletIcons? tabletIcon;
  final String? trail;
  final bool dividerBefore;
  final VoidCallback? onTap;
}

/// Exp/Web/AccountMenu (local, sync to DS; 1721:14019): a 272 card, radius
/// 14, the person over their items. It drops from the account chip, 12
/// from the right edge (tablet spec, Shell).
class IqWebAccountMenu extends StatelessWidget {
  const IqWebAccountMenu({
    super.key,
    required this.name,
    required this.email,
    required this.avatar,
    required this.items,
  });

  final String name;
  final String email;

  /// The person's avatar, drawn 40 across.
  final Widget avatar;
  final List<IqWebAccountMenuItem> items;

  static const double width = 272;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(IqSpace.s2),
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(IqRadius.xl),
        border: Border.all(color: IqColors.line),
        boxShadow: IqShadows.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s2,
              IqSpace.s2,
              IqSpace.s2,
              IqSpace.s3,
            ),
            child: Row(
              children: [
                ClipOval(
                  child: Container(
                    width: 40,
                    height: 40,
                    color: IqColors.tint,
                    child: avatar,
                  ),
                ),
                const SizedBox(width: IqSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IqWebText.bodySmallStrong.copyWith(
                          color: IqColors.fg,
                        ),
                      ),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IqWebText.metaCaption.copyWith(
                          color: IqColors.fg3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _Divider(),
          for (final item in items) ...[
            if (item.dividerBefore) const _Divider(),
            const SizedBox(height: IqSpace.s0p5),
            _Item(item),
          ],
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: ColoredBox(color: IqColors.line));
}

class _Item extends StatelessWidget {
  const _Item(this.item);

  final IqWebAccountMenuItem item;

  @override
  Widget build(BuildContext context) {
    final tablet = item.tabletIcon;
    return IqPressable(
      onTap: item.onTap,
      tactile: false,
      semanticLabel: item.label,
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: IqSpace.s2p5),
        decoration: BoxDecoration(
          color: pressed ? IqColors.secondary : null,
          borderRadius: BorderRadius.circular(IqRadius.md),
        ),
        child: Row(
          children: [
            if (tablet != null)
              IqTabletIcon(tablet, size: 18, color: IqColors.fg2)
            else
              IqIcon(item.icon!, size: 18, color: IqColors.fg2),
            const SizedBox(width: IqSpace.s3),
            Expanded(
              child: Text(
                item.label,
                style: IqWebText.bodySmall.copyWith(color: IqColors.fg),
              ),
            ),
            if (item.trail case final trail?)
              Text(
                trail,
                style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
              ),
          ],
        ),
      ),
    );
  }
}
