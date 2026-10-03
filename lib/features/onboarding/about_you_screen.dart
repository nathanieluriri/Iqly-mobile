import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../data/reference_data.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/chip.dart';
import '../../ui/icon.dart';
import '../../ui/step_mark.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';

/// B11 · Step 1 · About you (188:8171): occupation, one choice.
class AboutYouScreen extends ConsumerWidget {
  const AboutYouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occupation = ref.watch(
      onboardingDraftProvider.select((d) => d.profile.occupation),
    );
    final draft = ref.read(onboardingDraftProvider.notifier);
    void next() => goToStep(context, ref, OnboardingStep.whereYouLive);
    return OnboardingStepScaffold(
      step: IqStepMarkStep.oneOfThree,
      icon: IqIcons.profile,
      saved: occupation != null,
      title: 'What do you do?',
      onBack: () => context.go(Routes.onboarding, extra: NavDirection.back),
      onSkip: next,
      onNext: next,
      nextEnabled: occupation != null,
      child: Wrap(
        spacing: IqSpace.s2,
        runSpacing: IqSpace.s2,
        children: [
          for (final option in Reference.occupations)
            IqChip(
              label: option.label,
              state: option.value == occupation
                  ? IqChipState.selected
                  : IqChipState.standard,
              onChanged: (_) => draft.setOccupation(option.value),
            ),
        ],
      ),
    );
  }
}
