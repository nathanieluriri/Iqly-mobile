import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../data/reference_data.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/field.dart';
import '../../ui/step_mark.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';
import 'onboarding_sheets.dart';

/// B11 · Step 2 · Where you studied (223:10826): education (the option
/// sheet, 480:20164), then the university search (188:8340), whose "Add my
/// university" opens Add your university (480:20477). SSCE / WAEC has no
/// university, so the field folds away (1284:90545).
///
/// "Use this" in the university search moves on to What you like, as Figma
/// wires it (188:8380 to 188:8390), but only once the sheet has dropped and
/// the university has landed on this step (spec 6.15). Reduced motion: the
/// value lands and the step moves on at once.
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

  void _next() => goToStep(context, ref, OnboardingStep.whatYouLike);

  Future<void> _pickEducation(String? current) async {
    final picked = await showOnboardingSheet<String>(
      context,
      (context) => OptionSheet(
        title: 'Education',
        options: Reference.education,
        selected: current,
        confirm: 'Use this',
      ),
    );
    if (picked != null) {
      ref.read(onboardingDraftProvider.notifier).setEducation(picked);
    }
  }

  Future<void> _pickUniversity(String? current, String? state) async {
    String? adding;
    final picked = await showOnboardingSheet<String>(
      context,
      (context) => UniversitySheet(
        selected: current,
        state: state,
        onAdd: (query) => adding = query,
      ),
    );
    if (!mounted) return;
    final typed = adding;
    if (typed != null) {
      context.push(Routes.onboardingAddUniversity, extra: typed);
      return;
    }
    if (picked == null) return;
    ref.read(onboardingDraftProvider.notifier).setUniversity(picked);
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _landing.forward(from: 0).orCancel.catchError((_) {});
    }
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    _next();
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
      title: 'Where did you study?',
      onBack: () => leaveStep(context, Routes.onboardingWhereYouLive),
      onSkip: _next,
      onNext: _next,
      nextEnabled: education != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IqField(
            kind: IqFieldKind.picker,
            state: education == null ? IqFieldState.empty : IqFieldState.valid,
            pickerLabel: 'Education',
            pickerValue: education?.label ?? '',
            pickerPlaceholder: 'Select…',
            onTap: () => _pickEducation(profile.education),
          ),
          RevealSlot(
            shown: Reference.studiesAtUniversity(profile.education),
            child: Padding(
              padding: const EdgeInsets.only(top: IqSpace.s6),
              child: IqField(
                kind: IqFieldKind.picker,
                state: university == null
                    ? IqFieldState.empty
                    : IqFieldState.valid,
                pickerLabel: 'University',
                pickerValue: university ?? '',
                pickerPlaceholder: 'Search universities',
                onTap: () => _pickUniversity(university, profile.state),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
