import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'pressable.dart';

enum IqSegmentedSelected { first, second, third }

/// Exp/Segmented: the neutral segmented control for switching views of one
/// list (no brand fill). The selected option is a white pill on a grey
/// track. Two or three options; [option3] null drops the third.
///
/// Motion (designer answer 28): the chrome stays still; the pill and label
/// weight crossfade, 200 ms, and the list under it crossfades too. Reduced
/// motion cuts.
class IqSegmented extends StatelessWidget {
  const IqSegmented({
    super.key,
    this.option1 = 'All',
    this.option2 = 'Awards',
    this.option3 = 'Withdrawals',
    this.selected = IqSegmentedSelected.first,
    this.onChanged,
  });

  final String option1;
  final String option2;
  final String? option3;
  final IqSegmentedSelected selected;
  final ValueChanged<IqSegmentedSelected>? onChanged;

  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    final options = [option1, option2, ?option3];
    final fade = motion(context, IqDurations.swap);
    return Container(
      height: height,
      padding: const EdgeInsets.all(IqSpace.s1),
      decoration: BoxDecoration(
        color: IqColors.panel,
        borderRadius: BorderRadius.circular(IqRadius.full),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: IqSpace.s1),
            Expanded(
              child: _Option(
                label: options[i],
                selected: selected.index == i,
                fade: fade,
                onTap: onChanged == null
                    ? null
                    : () => onChanged!(IqSegmentedSelected.values[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.fade,
    this.onTap,
  });

  final String label;
  final bool selected;
  final Duration fade;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: IqPressable(
        onTap: onTap,
        semanticLabel: label,
        haptic: IqHaptics.select,
        builder: (context, pressed) => AnimatedContainer(
          duration: fade,
          curve: IqCurves.easeInOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? IqColors.card : IqColors.panel,
            borderRadius: BorderRadius.circular(IqRadius.full),
            boxShadow: selected ? IqShadows.xs : const [],
          ),
          child: AnimatedDefaultTextStyle(
            duration: fade,
            style: selected
                ? IqText.smallStrong.copyWith(color: IqColors.fg)
                : IqText.small.copyWith(color: IqColors.fg2),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}
