import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/reference_data.dart';
import '../../theme/theme.dart';
import '../../ui/field.dart';
import '../../ui/icon.dart';
import '../../ui/step_mark.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';
import 'onboarding_sheets.dart';

/// B11 · Step 2 · Where you studied (223:10826): education, then the
/// university search sheet.
class WhereYouStudiedScreen extends ConsumerWidget {
  const WhereYouStudiedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingDraftProvider).profile;
    final draft = ref.read(onboardingDraftProvider.notifier);
    final education = Reference.education
        .where((e) => e.value == profile.education)
        .firstOrNull;
    final university = profile.university;

    Future<void> pickEducation() async {
      final picked = await showOnboardingSheet(
        context,
        (context) => OptionSheet(
          title: 'Education',
          options: Reference.education,
          selected: profile.education,
        ),
      );
      if (picked != null) draft.setEducation(picked);
    }

    Future<void> pickUniversity() async {
      final picked = await showOnboardingSheet(
        context,
        (context) =>
            UniversitySheet(selected: university, state: profile.state),
      );
      if (picked == null || !context.mounted) return;
      draft.setUniversity(picked);
      goToStep(context, ref, OnboardingStep.whatYouLike);
    }

    return OnboardingStepScaffold(
      step: IqStepMarkStep.twoOfThree,
      icon: IqIcons.bank,
      saved: education != null || university != null,
      title: 'Where did you study?',
      onBack: () => goToStep(context, ref, OnboardingStep.whereYouLive),
      onSkip: () => goToStep(context, ref, OnboardingStep.whatYouLike),
      onNext: () => goToStep(context, ref, OnboardingStep.whatYouLike),
      nextEnabled: education != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IqField(
            kind: IqFieldKind.picker,
            size: IqFieldSize.large,
            state: education == null ? IqFieldState.empty : IqFieldState.valid,
            pickerLabel: 'Education',
            pickerValue: education?.label ?? '',
            pickerPlaceholder: 'Select…',
            onTap: pickEducation,
          ),
          const SizedBox(height: IqSpace.s6),
          IqField(
            kind: IqFieldKind.picker,
            size: IqFieldSize.large,
            state: university == null ? IqFieldState.empty : IqFieldState.valid,
            pickerLabel: 'University',
            pickerValue: university ?? '',
            pickerPlaceholder: 'Search universities',
            onTap: pickUniversity,
          ),
        ],
      ),
    );
  }
}
