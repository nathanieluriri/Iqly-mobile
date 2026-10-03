import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../data/reference_data.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/chip.dart';
import '../../ui/icon.dart';
import '../../ui/step_mark.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';

/// Figma chip labels are shorter than the shipped option labels; the stored
/// values are the shipped ones.
const interestChipLabels = {
  'tech_gadgets': 'Technology',
  'business_entrepreneurship': 'Business',
  'marketing_advertising': 'Marketing & advertising',
  'product_design_innovation': 'Product design',
  'finance_fintech': 'Finance & fintech',
  'agriculture_food': 'Agriculture & food',
  'education': 'Education',
  'health_wellness': 'Health',
  'energy_environment': 'Energy',
  'fashion_lifestyle': 'Fashion',
  'entertainment_social_media': 'Entertainment',
  'government_public_services': 'Government',
  'other': 'Other',
};

/// B11 · Step 3 · What you like (188:8390): interests order the feed.
/// Finish stays disabled under two picks.
class WhatYouLikeScreen extends ConsumerWidget {
  const WhatYouLikeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interests = ref.watch(
      onboardingDraftProvider.select((d) => d.profile.interests),
    );
    final draft = ref.read(onboardingDraftProvider.notifier);
    return OnboardingStepScaffold(
      step: IqStepMarkStep.threeOfThree,
      icon: IqIcons.discover,
      saved: interests.isNotEmpty,
      title: 'What are you into?',
      caption: 'Pick at least ${OnboardingDraft.minInterests}',
      onBack: () =>
          goToStep(context, ref, OnboardingStep.whereYouStudied, back: true),
      onSkip: () => _finish(context),
      onNext: () => _finish(context),
      nextEnabled: interests.length >= OnboardingDraft.minInterests,
      nextLabel: 'Finish',
      child: Wrap(
        spacing: IqSpace.s2,
        runSpacing: IqSpace.s2,
        children: [
          for (final option in Reference.interests)
            IqChip(
              label: interestChipLabels[option.value] ?? option.label,
              state: interests.contains(option.value)
                  ? IqChipState.selected
                  : IqChipState.standard,
              onChanged: (_) => draft.toggleInterest(option.value),
            ),
        ],
      ),
    );
  }
}

/// Finishing the steps lands the onboarding: the success haptic and Done.
void _finish(BuildContext context) {
  IqHaptics.success.play();
  context.go(Routes.onboardingDone);
}
