import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';

enum IqStepMarkStep {
  oneOfThree(0, 3),
  twoOfThree(1, 3),
  threeOfThree(2, 3),
  oneOfTwo(0, 2),
  twoOfTwo(1, 2),
  single(0, 1);

  /// The mark at [current] of [count] (1 to 3 steps).
  static IqStepMarkStep at(int current, int count) => values.firstWhere(
    (s) => s.count == count && s.current == current,
    orElse: () => single,
  );

  const IqStepMarkStep(this.current, this.count);

  final int current;
  final int count;
}

/// Exp/StepMark: the step progress, one 6 pt bar per step, 8 apart, filling
/// the width. Done and current bars are accent; the ones to come are line.
///
/// Figma over brief: since the 5 Oct update the mark is a segmented bar,
/// not the 44 pt ring with dots.
///
/// Motion (build extension): a bar that becomes current fills over 300 ms
/// ease-out; reduced motion cuts.
class IqStepMark extends StatelessWidget {
  const IqStepMark({super.key, this.step = IqStepMarkStep.oneOfThree});

  final IqStepMarkStep step;

  static const double height = 6;

  @override
  Widget build(BuildContext context) {
    final fill = motion(context, IqDurations.screen);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < step.count; i++) ...[
            if (i > 0) const SizedBox(width: IqSpace.s2),
            Expanded(
              child: AnimatedContainer(
                duration: fill,
                curve: IqCurves.easeOut,
                decoration: BoxDecoration(
                  color: i <= step.current ? IqColors.accent : IqColors.line,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
