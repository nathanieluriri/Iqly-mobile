import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'pressable.dart';
import 'vector.dart';

/// Figma State=Default is [standard].
enum IqOptionRowState { standard, selected }

/// Exp/OptionRow: a 56 high picker row for long lists (universities,
/// states, banks, sort). Selected is the tint fill with the check; the
/// label stays Regular. A pick gives the select haptic.
///
/// Figma over brief: the check is a plain 16 x 11.5 stroked tick (2.2 px), not the brush check icon.
/// Figma over brief: Default is a white Color/card row with radius 12.
class IqOptionRow extends StatelessWidget {
  const IqOptionRow({
    super.key,
    this.label = 'University of Lagos',
    this.note = 'Akoka, Lagos',
    this.showNote = true,
    this.state = IqOptionRowState.standard,
    this.onTap,
  });

  final String label;
  final String note;
  final bool showNote;
  final IqOptionRowState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final selected = state == IqOptionRowState.selected;
    return Semantics(
      selected: selected,
      child: IqPressable(
        onTap: onTap,
        semanticLabel: label,
        haptic: IqHaptics.select,
        builder: (context, pressed) => Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
          decoration: BoxDecoration(
            color: selected ? IqColors.tint : IqColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: IqText.body.copyWith(color: IqColors.fg),
                    ),
                    if (showNote) ...[
                      const SizedBox(height: 1),
                      Text(
                        note,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: IqText.small.copyWith(color: IqColors.fg3),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: IqSpace.s3),
                // The export carries 1.1 px of stroke bleed around the tick.
                SizedBox(
                  width: 16,
                  height: 11.5,
                  child: OverflowBox(
                    maxWidth: 19,
                    maxHeight: 14,
                    alignment: Alignment.topLeft,
                    child: Transform.translate(
                      offset: const Offset(-1.1, -1.1),
                      child: const IqVector(
                        'assets/vectors/option-row-check.svg',
                        color: IqColors.brand,
                        width: 19,
                        height: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
