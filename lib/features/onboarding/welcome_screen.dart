import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/list_row.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';

/// B11 · Welcome (188:8099): the hub before the three steps.
///
/// Motion (MOTION-SPEC 6.11): the Sprout rises in at 0 and its accent plays
/// at +160 (the ground line wipes, the sparks pop); eyebrow +80, title
/// +120, "About a minute" +160; the three rows arrive 40 apart from +200;
/// Start and Skip for now come with the page.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = ref.watch(greetingNameProvider);
    const rows = [
      IqListRow(
        label: 'About you',
        icon: IqIcons.profile,
        showDescription: false,
        showChevron: false,
      ),
      IqListRow(
        label: 'Where you live and study',
        icon: IqIcons.pin,
        showDescription: false,
        showChevron: false,
      ),
      IqListRow(
        label: 'What you’re into',
        icon: IqIcons.polls,
        showDescription: false,
        showChevron: false,
        divider: false,
      ),
    ];
    return OnboardingHeroScaffold(
      entrance:
          IqMomentTiming.rowsAt +
          IqDurations.stagger * (rows.length - 1) +
          BeatMove.arrive.length,
      hero: Padding(
        padding: const EdgeInsets.only(top: IqSpace.s2),
        child: Center(
          child: IqIllustration(
            IqIllustrations.sprout,
            width: 250,
            entrance: heroEntrance(context),
          ),
        ),
      ),
      eyebrow: 'Welcome',
      title: firstName == null
          ? 'Three quick steps'
          : 'Three quick steps, $firstName',
      content: [
        Beat(
          at: IqMomentTiming.bodyAt,
          child: Text(
            'About a minute',
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
        ),
        Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              Beat(
                at: IqMomentTiming.rowsAt + IqDurations.stagger * i,
                move: BeatMove.arrive,
                child: rows[i],
              ),
          ],
        ),
      ],
      actions: [
        IqButton(
          label: 'Start',
          showIcon: false,
          width: double.infinity,
          onTap: () => goToStep(context, ref, OnboardingStep.aboutYou),
        ),
        IqButton(
          label: 'Skip for now',
          kind: IqButtonKind.ghost,
          showIcon: false,
          width: double.infinity,
          onTap: () {
            ref.read(onboardingDraftProvider.notifier).defer();
            context.go(Routes.home);
          },
        ),
      ],
    );
  }
}
