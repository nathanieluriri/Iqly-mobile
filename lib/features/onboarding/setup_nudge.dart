import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../router.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';

/// B11 · Home · setup nudge (188:8570): the "Finish setting up" row Discover
/// shows under the feed chips while first run is unfinished. Hides itself
/// once onboarding is done.
class SetupNudge extends ConsumerWidget {
  const SetupNudge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionProvider.select((s) => s.onboardingDone))) {
      return const SizedBox.shrink();
    }
    final draft = ref.watch(onboardingDraftProvider);
    final left = draft.stepsLeft;
    return IqListRow(
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
    );
  }
}
