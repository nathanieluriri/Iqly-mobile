import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/deadline.dart';
import '../../data/onboarding_service.dart';
import '../../data/reference_data.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/chip.dart';
import '../../ui/field.dart';
import '../profile/profile_sheets.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';
import 'onboarding_sheets.dart';

/// Figma chip labels where they differ from the shipped option labels; the
/// stored values are the shipped ones.
const occupationChipLabels = {'unemployed': 'Looking for work'};

/// "12 Mar 2004", as Figma 188:8171 writes a date of birth.
String dateOfBirthLabel(DateTime date) => DateFormat('d MMM y').format(date);

/// B11 · Step 1 · About you (188:8171): occupation and date of birth. Under
/// 18 (480:20079) the banner says why, the field shows "Under 18" and
/// Continue stays off; Skip for now still moves on. A date the account
/// refused as under 18 comes back here cleared, under the same banner.
class AboutYouScreen extends ConsumerWidget {
  const AboutYouScreen({super.key});

  static const underAge =
      'You need to be 18 or older to join iQLY. Check your date of birth.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingDraftProvider);
    final profile = onboarding.profile;
    final occupation = profile.occupation;
    final born = profile.dateOfBirth;
    final today = ref.watch(clockProvider)();
    final tooYoung = born != null && !isAdult(born, today);
    final draft = ref.read(onboardingDraftProvider.notifier);
    void next() => goToNextStep(context, ref, OnboardingStep.aboutYou);

    Future<void> pickDate() async {
      final picked = await showOnboardingSheet<DateTime>(
        context,
        (context) => DateOfBirthSheet(initial: born, today: today),
      );
      if (picked != null) draft.setDateOfBirth(picked);
    }

    return OnboardingStepScaffold(
      step: OnboardingStep.aboutYou.mark,
      title: 'What do you do?',
      banner: tooYoung || onboarding.underAge ? underAge : null,
      onBack: () => leaveStep(context, Routes.onboarding),
      onSkip: next,
      onNext: next,
      nextEnabled: occupation != null && born != null && !tooYoung,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: IqSpace.s2,
            runSpacing: IqSpace.s2,
            children: [
              for (final option in Reference.occupations)
                IqChip(
                  label: occupationChipLabels[option.value] ?? option.label,
                  state: option.value == occupation
                      ? IqChipState.selected
                      : IqChipState.standard,
                  onChanged: (_) => draft.setOccupation(option.value),
                ),
            ],
          ),
          const SizedBox(height: IqSpace.s6),
          IqField(
            kind: IqFieldKind.picker,
            state: born == null
                ? IqFieldState.empty
                : tooYoung
                ? IqFieldState.error
                : IqFieldState.valid,
            pickerLabel: 'Date of birth',
            pickerValue: born == null ? '' : dateOfBirthLabel(born),
            pickerPlaceholder: 'Select…',
            help: 'Under 18',
            onTap: pickDate,
          ),
        ],
      ),
    );
  }
}
