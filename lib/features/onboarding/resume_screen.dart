import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../theme/theme.dart';
import '../../ui/illustration.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';

/// B11 · Resume (188:8443): what the app opens on when first run was left
/// mid-flow. Continue and Start over push the step over it.
///
/// Motion (MOTION-SPEC 6.17): the Cheer figure rises in; title +120 and
/// "Next:" +160.
class ResumeScreen extends ConsumerWidget {
  const ResumeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = ref.watch(greetingNameProvider);
    final next =
        ref.watch(onboardingDraftProvider.select((d) => d.lastStep)) ??
        OnboardingStep.gender;
    return OnboardingHeroScaffold(
      figure: IqFigures.cheer,
      title: firstName == null ? 'Welcome back' : 'Welcome back, $firstName',
      content: [
        const SizedBox(height: IqSpace.s4),
        Beat(
          at: IqMomentTiming.bodyAt,
          child: Text(
            'Next: ${next.label}',
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
        ),
      ],
      primary: 'Continue',
      onPrimary: () => goToStep(context, ref, next),
      ghost: 'Start over',
      onGhost: () {
        ref.read(onboardingDraftProvider.notifier).startOver();
        goToStep(context, ref, OnboardingStep.gender);
      },
    );
  }
}
