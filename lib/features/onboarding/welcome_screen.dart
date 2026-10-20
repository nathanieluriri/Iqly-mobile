import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/list_row.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';

/// B11 · Welcome (188:8099): the hub before the three steps.
///
/// Motion (MOTION-SPEC 6.11): the Shrug rises in at 0; title +120, "About a
/// minute" +160; the group's three rows arrive 40 apart from +200; Start and
/// Skip for now come with the page.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  static const _rows = [
    (label: 'About you', icon: IqIcons.profile),
    (label: 'Where you live and study', icon: IqIcons.pin),
    (label: 'What you’re into', icon: IqIcons.polls),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = ref.watch(greetingNameProvider);
    return OnboardingHeroScaffold(
      figure: IqFigures.shrug,
      entrance:
          IqMomentTiming.rowsAt +
          IqDurations.stagger * (_rows.length - 1) +
          BeatMove.arrive.length,
      title: firstName == null
          ? 'Three quick steps'
          : 'Three quick steps, $firstName',
      content: [
        const SizedBox(height: IqSpace.s4),
        Beat(
          at: IqMomentTiming.bodyAt,
          child: Text(
            'About a minute',
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
        ),
        const SizedBox(height: IqSpace.s4),
        OnboardingGroup(
          children: [
            for (final (i, row) in _rows.indexed)
              Beat(
                at: IqMomentTiming.rowsAt + IqDurations.stagger * i,
                move: BeatMove.arrive,
                child: IqListRow(
                  label: row.label,
                  icon: row.icon,
                  showDescription: false,
                  showChevron: false,
                  divider: i < _rows.length - 1,
                ),
              ),
          ],
        ),
      ],
      primary: 'Start',
      onPrimary: () => goToStep(context, ref, OnboardingStep.gender),
      ghost: 'Skip for now',
      onGhost: () {
        ref.read(onboardingDraftProvider.notifier).defer();
        context.go(Routes.home);
      },
    );
  }
}
