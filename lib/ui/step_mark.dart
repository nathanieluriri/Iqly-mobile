import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';

enum IqStepMarkStep {
  oneOfThree(0, 3),
  twoOfThree(1, 3),
  threeOfThree(2, 3),
  single(0, 1);

  const IqStepMarkStep(this.current, this.count);

  final int current;
  final int count;
}

/// Exp/StepMark: the Hinge-style step marker. The current step is a 44 pt
/// ring around a brush [icon]; the other steps are 6 pt dots, done and
/// upcoming alike.
///
/// Figma over brief: every variant ships with the profile icon; the swap is a nested override, exposed here as [icon].
class IqStepMark extends StatelessWidget {
  const IqStepMark({
    super.key,
    this.step = IqStepMarkStep.oneOfThree,
    this.icon = IqIcons.profile,
  });

  final IqStepMarkStep step;
  final IqIcons icon;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < step.count; i++) {
      if (i > 0) children.add(const SizedBox(width: IqSpace.s3));
      children.add(i == step.current ? _ring() : _dot);
    }
    return Semantics(
      label: 'Step ${step.current + 1} of ${step.count}',
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _ring() => Container(
    width: 44,
    height: 44,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: IqColors.brand, width: 2),
    ),
    child: IqIcon(icon, size: 22, color: IqColors.brand),
  );

  static const _dot = SizedBox.square(
    dimension: 6,
    child: DecoratedBox(
      decoration: BoxDecoration(color: IqColors.line2, shape: BoxShape.circle),
    ),
  );
}
