import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../data/assessment_data.dart';
import '../../data/assessment_service.dart';
import '../../router.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../onboarding/onboarding_layout.dart';

/// Discover row, same group as "Finish setting up": a short check-in before
/// new briefs, or continue an unfinished run. Folds away after a pass.
class AssessmentNudge extends ConsumerWidget {
  const AssessmentNudge({super.key, this.gap = 0});

  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = assessmentNudge(ref.watch(assessmentAccessProvider).value);
    return Collapse(
      open: copy != null,
      child: Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: OnboardingGroup(
          children: [
            IqListRow(
              label: copy?.label ?? '',
              description: copy?.description ?? '',
              showDescription: copy?.description != null,
              icon: IqIcons.sparkles,
              divider: false,
              onTap: () => context.open(Routes.assessment),
            ),
          ],
        ),
      ),
    );
  }
}
