import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'pressable.dart';

/// Figma State=Default is [standard].
enum IqBizSegmentState { standard, selected }

/// Exp/Biz/Segment (1725:152822): one tab of a segmented control, radius 8,
/// 12 by 6 padding. Selected is white with an fg Medium label; the others
/// are clear with an fg2 Regular label. Lay them 2 apart on
/// [IqBizSegment.track], which keeps the row 44 tall for touch.
class IqBizSegment extends StatelessWidget {
  const IqBizSegment({
    super.key,
    required this.label,
    this.state = IqBizSegmentState.standard,
    this.onTap,
  });

  final String label;
  final IqBizSegmentState state;
  final VoidCallback? onTap;

  /// The grey track the segments sit on: 3 in, radius 10.
  static Widget track({required List<Widget> children}) => Container(
    height: 44,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: IqColors.secondary,
      borderRadius: BorderRadius.circular(IqRadius.lg),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const SizedBox(width: IqSpace.s0p5),
          child,
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final on = state == IqBizSegmentState.selected;
    return Semantics(
      selected: on,
      button: true,
      child: IqPressable(
        onTap: on ? null : onTap,
        tactile: false,
        builder: (context, pressed) => Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: IqSpace.s3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on
                ? IqColors.card
                : pressed
                ? IqColors.secondaryHover
                : null,
            borderRadius: BorderRadius.circular(IqRadius.md),
            boxShadow: on ? IqShadows.xs : null,
          ),
          child: Text(
            label,
            style: (on ? IqWebText.bodySmallStrong : IqWebText.bodySmall)
                .copyWith(color: on ? IqColors.fg : IqColors.fg2),
          ),
        ),
      ),
    );
  }
}
