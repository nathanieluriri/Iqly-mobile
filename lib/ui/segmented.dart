import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'pressable.dart';

enum IqSegmentedSelected { first, second, third }

/// Exp/Segmented: the neutral segmented control for switching views of one
/// list (no brand fill). The selected option is a white pill on a grey
/// track. Two or three options; [option3] null drops the third.
///
/// Motion (owner, 16 Oct): the pill slides to the picked option, 260 ms
/// ease-in-out, as the labels cross weight and ink; whatever the control
/// switches slides with it ([LensSlide]). Reduced motion: the pill moves at
/// once.
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
    final slide = motion(context, IqDurations.lensSlide);
    return Container(
      height: height,
      padding: const EdgeInsets.all(IqSpace.s1),
      decoration: BoxDecoration(
        color: IqColors.panel,
        borderRadius: BorderRadius.circular(IqRadius.full),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = IqSpace.s1;
          final width =
              (box.maxWidth - gap * (options.length - 1)) / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                key: const ValueKey('pill'),
                duration: slide,
                curve: IqCurves.easeInOut,
                left: selected.index * (width + gap),
                top: 0,
                bottom: 0,
                width: width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: IqColors.card,
                    borderRadius: BorderRadius.circular(IqRadius.full),
                    boxShadow: IqShadows.xs,
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < options.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Expanded(
                      child: _Option(
                        label: options[i],
                        selected: selected.index == i,
                        fade: slide,
                        onTap: onChanged == null
                            ? null
                            : () => onChanged!(IqSegmentedSelected.values[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
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
        builder: (context, pressed) => Center(
          child: AnimatedDefaultTextStyle(
            duration: fade,
            curve: IqCurves.easeInOut,
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
