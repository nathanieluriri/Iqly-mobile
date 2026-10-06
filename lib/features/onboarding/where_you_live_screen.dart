import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/theme.dart';
import '../../ui/field.dart';
import '../../ui/step_mark.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';
import 'onboarding_sheets.dart';
import '../../router.dart';

/// B11 · Step 2 · Where you are (188:8255): state of residence, city and
/// the optional phone number (answer 17).
///
/// Owner over Figma: City is a picker over the city list (the brief's
/// picker) where the frame draws a Text field; its slot keeps the frame's
/// 86 pt height. A picked value lands once its sheet has dropped (spec
/// 6.13).
class WhereYouLiveScreen extends ConsumerStatefulWidget {
  const WhereYouLiveScreen({super.key});

  @override
  ConsumerState<WhereYouLiveScreen> createState() => _WhereYouLiveScreenState();
}

class _WhereYouLiveScreenState extends ConsumerState<WhereYouLiveScreen> {
  late final _phone = TextEditingController(
    text: ref.read(onboardingDraftProvider).profile.phone,
  );

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(onboardingDraftProvider).profile;
    final draft = ref.read(onboardingDraftProvider.notifier);
    final city = profile.city.trim();
    final state = profile.state;
    void next() => goToStep(context, ref, OnboardingStep.whereYouStudied);

    Future<void> pickState() async {
      final picked = await showOnboardingSheet<String>(
        context,
        (context) => OptionSheet(
          title: 'State',
          options: residenceOptions,
          selected: state,
          search: 'Search states',
          confirm: 'Use this',
        ),
      );
      if (picked != null) draft.setState(picked);
    }

    Future<void> pickCity() async {
      final picked = await showOnboardingSheet<String>(
        context,
        (context) =>
            CityPickerFlow(state: state, city: city, onState: draft.setState),
      );
      if (picked != null) draft.setCity(picked);
    }

    return OnboardingStepScaffold(
      step: IqStepMarkStep.twoOfThree,
      title: 'Where do you live?',
      onBack: () => leaveStep(context, Routes.onboardingAboutYou),
      onSkip: next,
      onNext: next,
      nextEnabled: state != null && city.isNotEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IqField(
            kind: IqFieldKind.picker,
            state: state == null ? IqFieldState.empty : IqFieldState.valid,
            pickerLabel: 'State',
            pickerValue: state == null ? '' : stateLabel(state),
            pickerPlaceholder: 'Select state',
            onTap: pickState,
          ),
          const SizedBox(height: IqSpace.s6),
          SizedBox(
            height: _citySlot,
            child: Align(
              alignment: Alignment.topCenter,
              child: IqField(
                kind: IqFieldKind.picker,
                state: city.isEmpty ? IqFieldState.empty : IqFieldState.valid,
                pickerLabel: 'City',
                pickerValue: city,
                pickerPlaceholder: 'Select city',
                onTap: pickCity,
              ),
            ),
          ),
          const SizedBox(height: IqSpace.s6),
          IqField(
            label: 'Phone number (optional)',
            value: '+234',
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.done,
            showStatus: false,
            showNote: false,
            onChanged: (value) => draft.setPhone(value.trim()),
          ),
        ],
      ),
    );
  }

  /// Figma's City is a Text field with its note slot open (86 pt).
  static const double _citySlot = 86;
}
