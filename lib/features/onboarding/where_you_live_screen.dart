import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/theme.dart';
import '../../ui/field.dart';
import '../../ui/icon.dart';
import '../../ui/step_mark.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';
import 'onboarding_sheets.dart';

/// B11 · Step 2 · Where you are (188:8255): state of residence and city.
///
/// Owner over Figma: CITY is a picker over the city list (the brief's picker)
/// where the frame draws a Text field. A city typed before the list existed,
/// or added with "Add my city", shows as it was saved. A picked value lands
/// once its sheet has dropped (spec 6.13).
class WhereYouLiveScreen extends ConsumerWidget {
  const WhereYouLiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingDraftProvider).profile;
    final draft = ref.read(onboardingDraftProvider.notifier);
    final city = profile.city.trim();

    Future<void> pickState() async {
      final picked = await showOnboardingSheet<String>(
        context,
        hug: true,
        (context) => OptionSheet(
          title: 'State of residence',
          options: stateOptions,
          selected: profile.state,
        ),
      );
      if (picked != null) draft.setState(picked);
    }

    Future<void> pickCity() async {
      final picked = await showOnboardingSheet<String>(
        context,
        (context) => CityPickerFlow(
          state: profile.state,
          city: city,
          onState: draft.setState,
        ),
      );
      if (picked != null) draft.setCity(picked);
    }

    return OnboardingStepScaffold(
      step: IqStepMarkStep.twoOfThree,
      icon: IqIcons.pin,
      saved: profile.state != null || city.isNotEmpty,
      answer: (profile.state, city),
      title: 'Where do you live?',
      onBack: () => goToStep(context, ref, OnboardingStep.aboutYou, back: true),
      onSkip: () => goToStep(context, ref, OnboardingStep.whatYouLike),
      onNext: () => goToStep(context, ref, OnboardingStep.whereYouStudied),
      nextEnabled: profile.state != null && city.isNotEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IqField(
            kind: IqFieldKind.picker,
            size: IqFieldSize.large,
            state: profile.state == null
                ? IqFieldState.empty
                : IqFieldState.valid,
            pickerLabel: 'State of residence',
            pickerValue: profile.state ?? '',
            pickerPlaceholder: 'Select state',
            onTap: pickState,
          ),
          const SizedBox(height: IqSpace.s6),
          IqField(
            kind: IqFieldKind.picker,
            size: IqFieldSize.large,
            state: city.isEmpty ? IqFieldState.empty : IqFieldState.valid,
            pickerLabel: 'City',
            pickerValue: city,
            pickerPlaceholder: 'Select city',
            onTap: pickCity,
          ),
        ],
      ),
    );
  }
}
