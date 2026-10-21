import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// Figma State=Default is [standard].
enum IqBizFilterChipState { standard, active }

/// Exp/Biz/FilterChip (1725:152838): the 44 tall toolbar chip, radius 8.
/// Default is white on the line with an fg2 label and the chevron (Filters,
/// Sort); Active is grey on line2 with an fg Medium label and the clear
/// cross (an applied filter, or Filters while its popover is open).
class IqBizFilterChip extends StatelessWidget {
  const IqBizFilterChip({
    super.key,
    required this.label,
    this.state = IqBizFilterChipState.standard,
    this.onTap,
    this.onClear,
  });

  final String label;
  final IqBizFilterChipState state;
  final VoidCallback? onTap;

  /// The cross of an Active chip; tapping it clears. Without it the whole
  /// chip takes [onTap].
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final active = state == IqBizFilterChipState.active;
    return IqPressable(
      onTap: active && onClear != null && onTap == null ? onClear : onTap,
      tactile: false,
      semanticLabel: active && onClear != null ? 'Clear $label' : label,
      builder: (context, pressed) => Container(
        height: 44,
        padding: const EdgeInsets.only(left: IqSpace.s3, right: IqSpace.s2p5),
        decoration: BoxDecoration(
          color: active || pressed ? IqColors.secondary : IqColors.card,
          borderRadius: BorderRadius.circular(IqRadius.md),
          border: Border.all(color: active ? IqColors.line2 : IqColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: (active ? IqWebText.bodySmallStrong : IqWebText.bodySmall)
                  .copyWith(color: active ? IqColors.fg : IqColors.fg2),
            ),
            const SizedBox(width: IqSpace.s1p5),
            IqIcon(
              active ? IqIcons.close : IqIcons.down,
              size: 16,
              color: IqColors.fg,
            ),
          ],
        ),
      ),
    );
  }
}
