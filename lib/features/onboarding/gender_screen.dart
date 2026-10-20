import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/reference_data.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/chip.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';

/// Under the gender choices here and on Edit · Gender.
const genderHelp = 'We use this to show you challenges meant for you.';

/// B11 · Step 1 · Your gender (1599:32935, picked 1599:33021): the first
/// step, required (owner, 20 Oct), so it has no Skip for now. "Prefer not
/// to say" is a choice like the others.
class GenderScreen extends ConsumerWidget {
  const GenderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gender = ref.watch(
      onboardingDraftProvider.select((d) => d.profile.gender),
    );
    final draft = ref.read(onboardingDraftProvider.notifier);
    return OnboardingStepScaffold(
      step: OnboardingStep.gender.mark,
      title: 'What’s your gender?',
      onBack: () => leaveStep(context, Routes.onboarding),
      onNext: () => goToNextStep(context, ref, OnboardingStep.gender),
      nextEnabled: gender != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: IqSpace.s2,
            runSpacing: IqSpace.s2,
            children: [
              for (final option in Reference.genders)
                IqChip(
                  label: option.label,
                  state: option.value == gender
                      ? IqChipState.selected
                      : IqChipState.standard,
                  onChanged: (_) => draft.setGender(option.value),
                ),
            ],
          ),
          const SizedBox(height: IqSpace.s6),
          Text(genderHelp, style: IqText.small.copyWith(color: IqColors.fg2)),
        ],
      ),
    );
  }
}
