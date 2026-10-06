import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/session.dart';
import '../../router.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';

/// B11 · Home · setup nudge (188:8570): the "Finish setting up" group Discover
/// shows under the feed chips while first run is unfinished, with [gap]
/// under it. Once onboarding is done it folds away with its gap (spec 6.19:
/// 200 ms ease-in, playing the next time Home is on screen, since its clock
/// stands still while Home is covered); it never shows when first run was
/// already done.
class SetupNudge extends ConsumerStatefulWidget {
  const SetupNudge({super.key, this.gap = 0});

  final double gap;

  @override
  ConsumerState<SetupNudge> createState() => _SetupNudgeState();
}

class _SetupNudgeState extends ConsumerState<SetupNudge> {
  late final bool _shown = !ref.read(
    sessionProvider.select((s) => s.onboardingDone),
  );

  @override
  Widget build(BuildContext context) {
    final done = ref.watch(sessionProvider.select((s) => s.onboardingDone));
    if (!_shown) return const SizedBox.shrink();
    final draft = ref.watch(onboardingDraftProvider);
    final left = draft.stepsLeft;
    return Collapse(
      open: !done,
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.gap),
        child: OnboardingGroup(
          children: [
            IqListRow(
              label: 'Finish setting up',
              description: '$left ${left == 1 ? 'step' : 'steps'} left',
              icon: IqIcons.profile,
              divider: false,
              onTap: () {
                final step = draft.firstIncomplete;
                if (step == null) {
                  context.go(Routes.onboardingDone);
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
