import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/reference_data.dart';
import '../../theme/theme.dart';
import '../../ui/chip.dart';
import 'onboarding_draft.dart';
import 'onboarding_flow.dart';
import 'onboarding_layout.dart';
import 'what_you_like_screen.dart';

/// The work question, worded for what someone does (owner, 16 Oct).
const workQuestions = {
  'entrepreneur': 'What does your business do?',
  'employed': 'Which sector do you work in?',
  'self_employed': 'What kind of work do you do?',
  'unemployed': 'Which sector do you want to work in?',
  'other': 'Which sector are you closest to?',
};

String workQuestion(String? occupation) =>
    workQuestions[occupation] ?? workQuestions['other']!;

/// The sector chips: one pick, and Other opens a field for their own words.
class SectorChips extends StatelessWidget {
  const SectorChips({
    super.key,
    required this.sector,
    required this.otherSector,
    required this.onSector,
    required this.onOtherSector,
  });

  final String? sector;
  final String otherSector;
  final ValueChanged<String> onSector;
  final ValueChanged<String> onOtherSector;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: IqSpace.s2,
          runSpacing: IqSpace.s2,
          children: [
            for (final option in Reference.sectors)
              IqChip(
                label: option.label,
                state: option.value == sector
                    ? IqChipState.selected
                    : IqChipState.standard,
                onChanged: (_) => onSector(option.value),
              ),
          ],
        ),
        OtherInterestField(
          shown: sector == OnboardingFlow.otherSector,
          value: otherSector,
          label: 'Your sector',
          onChanged: onOtherSector,
        ),
      ],
    );
  }
}

/// B11 · Step 2 · Your work: on the occupation path, anyone but a student
/// says what their work is instead of where they study, before where they
/// live. Continue stays off until a sector is picked, and while Other is
/// picked without its words.
class YourWorkScreen extends ConsumerWidget {
  const YourWorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingDraftProvider.select((d) => d.profile));
    final draft = ref.read(onboardingDraftProvider.notifier);
    void next() => goToNextStep(context, ref, OnboardingStep.yourWork);
    return OnboardingStepScaffold(
      step: OnboardingStep.yourWork.mark,
      title: workQuestion(profile.occupation),
      caption: 'Pick one',
      onBack: () => leaveToPrevious(context, ref, OnboardingStep.yourWork),
      onSkip: next,
      onNext: next,
      nextEnabled: OnboardingFlow.workAnswered(profile),
      child: SectorChips(
        sector: profile.sector,
        otherSector: profile.otherSector,
        onSector: draft.setSector,
        onOtherSector: draft.setOtherSector,
      ),
    );
  }
}
