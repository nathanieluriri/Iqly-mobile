import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
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
///
/// "Use this" moves on to What you like, as Figma wires it (188:8380 to
/// 188:8390), but only once the sheet has dropped and the university has
/// landed on this step: the value crosses over, its check pops and the
/// autosave check re-stamps, then a beat later the step moves on (spec
/// 6.15). Reduced motion: the value lands and the step moves on at once.
class WhereYouStudiedScreen extends ConsumerStatefulWidget {
  const WhereYouStudiedScreen({super.key});

  @override
  ConsumerState<WhereYouStudiedScreen> createState() =>
      _WhereYouStudiedScreenState();
}

class _WhereYouStudiedScreenState extends ConsumerState<WhereYouStudiedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _landing = AnimationController(
    vsync: this,
    duration: IqDurations.appear + IqDurations.chain,
  );

  @override
  void dispose() {
    _landing.dispose();
    super.dispose();
  }

  Future<void> _pickEducation(String? current) async {
    final picked = await showOnboardingSheet<String>(
      context,
      hug: true,
      (context) => OptionSheet(
        title: 'Education',
        options: Reference.education,
        selected: current,
      ),
    );
    if (picked != null) {
      ref.read(onboardingDraftProvider.notifier).setEducation(picked);
    }
  }

  Future<void> _pickUniversity(String? current, String? state) async {
    final picked = await showOnboardingSheet<String>(
      context,
      (context) => UniversitySheet(selected: current, state: state),
    );
    if (picked == null || !mounted) return;
    ref.read(onboardingDraftProvider.notifier).setUniversity(picked);
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _landing.forward(from: 0).orCancel.catchError((_) {});
    }
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    goToStep(context, ref, OnboardingStep.whatYouLike);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(onboardingDraftProvider).profile;
    final education = Reference.education
        .where((e) => e.value == profile.education)
        .firstOrNull;
    final university = profile.university;

    return OnboardingStepScaffold(
      step: IqStepMarkStep.twoOfThree,
      icon: IqIcons.bank,
      saved: education != null || university != null,
      answer: (education, university),
      title: 'Where did you study?',
      onBack: () =>
          goToStep(context, ref, OnboardingStep.whereYouLive, back: true),
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
            onTap: () => _pickEducation(profile.education),
          ),
          const SizedBox(height: IqSpace.s6),
          IqField(
            kind: IqFieldKind.picker,
            size: IqFieldSize.large,
            state: university == null ? IqFieldState.empty : IqFieldState.valid,
            pickerLabel: 'University',
            pickerValue: university ?? '',
            pickerPlaceholder: 'Search universities',
            onTap: () => _pickUniversity(university, profile.state),
          ),
        ],
      ),
    );
  }
}
