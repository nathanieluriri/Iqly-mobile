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

/// B11 · Step 2 · Where you are (188:8255): state of residence and city.
///
/// City is free text, as in Figma and the shipped profile form; there is no
/// city list to pick from.
class WhereYouLiveScreen extends ConsumerStatefulWidget {
  const WhereYouLiveScreen({super.key});

  @override
  ConsumerState<WhereYouLiveScreen> createState() => _WhereYouLiveState();
}

class _WhereYouLiveState extends ConsumerState<WhereYouLiveScreen> {
  late final _city = TextEditingController(
    text: ref.read(onboardingDraftProvider).profile.city,
  );
  final _cityFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _cityFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _city.dispose();
    _cityFocus.dispose();
    super.dispose();
  }

  Future<void> _pickState(String? current) async {
    final picked = await showOnboardingSheet(
      context,
      (context) => OptionSheet(
        title: 'State of residence',
        options: [for (final s in Reference.states) RefOption(s, s)],
        selected: current,
      ),
    );
    if (picked != null) {
      ref.read(onboardingDraftProvider.notifier).setState(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(onboardingDraftProvider).profile;
    final city = profile.city.trim();
    final valid = profile.state != null && city.isNotEmpty;
    return OnboardingStepScaffold(
      step: IqStepMarkStep.twoOfThree,
      icon: IqIcons.pin,
      saved: profile.state != null || city.isNotEmpty,
      title: 'Where do you live?',
      onBack: () => goToStep(context, ref, OnboardingStep.aboutYou),
      onSkip: () => goToStep(context, ref, OnboardingStep.whatYouLike),
      onNext: () => goToStep(context, ref, OnboardingStep.whereYouStudied),
      nextEnabled: valid,
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
            onTap: () => _pickState(profile.state),
          ),
          const SizedBox(height: IqSpace.s6),
          IqField(
            size: IqFieldSize.large,
            state: !_cityFocus.hasFocus && city.isNotEmpty
                ? IqFieldState.valid
                : null,
            label: 'City',
            value: '',
            note: '',
            controller: _city,
            focusNode: _cityFocus,
            textInputAction: TextInputAction.done,
            onChanged: ref.read(onboardingDraftProvider.notifier).setCity,
          ),
        ],
      ),
    );
  }
}
