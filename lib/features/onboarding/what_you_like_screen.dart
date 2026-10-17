import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/reference_data.dart';
import '../../core/motion.dart';
import '../../theme/theme.dart';
import '../../ui/chip.dart';
import '../../ui/field.dart';
import '../../ui/toast.dart';
import 'done_screen.dart';
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

/// B11 · Step 3 · What you like (188:8390, with the 2 or 3 rule frames
/// 1284:68479 to 1284:90430): interests order the feed. Finish stays off
/// until 2 or 3 are picked, and while Other is picked without its words;
/// Finish and Skip for now end first run. Start here's briefs load while the
/// interests are picked, so the hand-off rarely waits for them.
class WhatYouLikeScreen extends ConsumerWidget {
  const WhatYouLikeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(startHereBriefsProvider, (_, _) {});
    final profile = ref.watch(onboardingDraftProvider.select((d) => d.profile));
    final draft = ref.read(onboardingDraftProvider.notifier);
    return OnboardingStepScaffold(
      step: OnboardingStep.whatYouLike.mark,
      title: 'What are you into?',
      caption: interestsCaption,
      onBack: () => leaveToPrevious(context, ref, OnboardingStep.whatYouLike),
      onSkip: () => finishOnboarding(context, ref, skipped: true),
      onNext: () => finishOnboarding(context, ref),
      nextEnabled: OnboardingDraft.interestsComplete(profile),
      nextLabel: 'Finish',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InterestChips(
            selected: profile.interests,
            onToggle: draft.toggleInterest,
          ),
          OtherInterestField(
            shown: profile.interests.contains(OnboardingDraft.otherInterest),
            value: profile.otherInterest,
            onChanged: draft.setOtherInterest,
          ),
        ],
      ),
    );
  }
}

const interestsCaption =
    'Pick ${OnboardingDraft.minInterests} or ${OnboardingDraft.maxInterests}';

/// The words for a 4th pick, shown in the Error toast.
const interestLimitMessage =
    'Max ${OnboardingDraft.maxInterests} interests. Unselect one first.';

/// The 13 interest chips, shared with Profile's interests sheet. Up to
/// [OnboardingDraft.maxInterests] can be picked: a further tap is refused
/// with a shake, the chip's error flash, the error haptic and a toast, and
/// [onToggle] is not called.
class InterestChips extends StatefulWidget {
  const InterestChips({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  final List<String> selected;
  final void Function(String value) onToggle;

  @override
  State<InterestChips> createState() => _InterestChipsState();
}

class _InterestChipsState extends State<InterestChips>
    with SingleTickerProviderStateMixin {
  final _shakes = <String, int>{};
  String? _refused;
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: IqDurations.refused,
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_flashEnded);

  void _flashEnded(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _refused = null);
    }
  }

  bool get _full => widget.selected.length >= OnboardingDraft.maxInterests;

  void _tap(String value) {
    if (widget.selected.contains(value) || !_full) {
      return widget.onToggle(value);
    }
    setState(() {
      _shakes[value] = (_shakes[value] ?? 0) + 1;
      _refused = value;
    });
    _flash.forward(from: 0);
    IqHaptics.error.play();
    IqToast.show(context, interestLimitMessage, kind: IqToastKind.error);
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: IqSpace.s2,
      runSpacing: IqSpace.s2,
      children: [
        for (final option in Reference.interests)
          Shake(
            trigger: _shakes[option.value] ?? 0,
            child: IqChip(
              label: interestChipLabels[option.value] ?? option.label,
              state: widget.selected.contains(option.value)
                  ? IqChipState.selected
                  : IqChipState.standard,
              refused: _refused == option.value,
              haptic: _full && !widget.selected.contains(option.value)
                  ? null
                  : IqHaptics.select,
              onChanged: (_) => _tap(option.value),
            ),
          ),
      ],
    );
  }
}

/// The Other interest's words (Exp/Field, frame 1284:90430): it opens under
/// the chips while Other is picked, taking the keyboard when the pick is
/// new, so a field that opens below the fold scrolls into view.
class OtherInterestField extends StatefulWidget {
  const OtherInterestField({
    super.key,
    required this.shown,
    required this.value,
    required this.onChanged,
    this.label = 'Other interest',
  });

  final bool shown;
  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  State<OtherInterestField> createState() => _OtherInterestFieldState();
}

class _OtherInterestFieldState extends State<OtherInterestField> {
  late final _words = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void didUpdateWidget(OtherInterestField old) {
    super.didUpdateWidget(old);
    if (widget.shown == old.shown) return;
    widget.shown ? _focus.requestFocus() : _focus.unfocus();
  }

  @override
  void dispose() {
    _words.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RevealSlot(
      shown: widget.shown,
      child: Padding(
        padding: const EdgeInsets.only(top: IqSpace.s3),
        child: IqField(
          label: widget.label,
          value: '',
          state: _words.text.trim().isEmpty ? null : IqFieldState.valid,
          showNote: false,
          controller: _words,
          focusNode: _focus,
          textInputAction: TextInputAction.done,
          inputFormatters: [LengthLimitingTextInputFormatter(60)],
          onChanged: (text) {
            setState(() {});
            widget.onChanged(text);
          },
        ),
      ),
    );
  }
}
