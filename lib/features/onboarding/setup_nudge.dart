import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import 'done_screen.dart';
import 'onboarding_layout.dart';
import 'setup_nudge_state.dart';

/// B11 · Home · setup nudge (188:8570): the "Finish setting up" group Discover
/// shows under the feed chips while first run is unfinished, with [gap]
/// under it. Once onboarding is done it folds away with its gap (spec 6.19:
/// 200 ms ease-in, playing the next time Home is on screen, since its clock
/// stands still while Home is covered); it never shows when first run was
/// already done.
class SetupNudge extends ConsumerWidget {
  const SetupNudge({super.key, this.gap = 0});

  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(setupNudgeStateProvider);
    final left = state.stepsLeft;
    return Collapse(
      open: state.visible,
      child: Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: OnboardingGroup(
          children: [
            IqListRow(
              label: 'Finish setting up',
              description: '$left ${left == 1 ? 'step' : 'steps'} left',
              icon: IqIcons.profile,
              divider: false,
              onTap: () {
                final step = state.firstIncomplete;
                if (step == null) {
                  finishOnboarding(context, ref);
                } else {
                  goToStep(context, ref, step);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
