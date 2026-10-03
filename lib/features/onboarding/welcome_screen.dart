import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/list_row.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';

/// B11 · Welcome (188:8099): the hub before the three steps.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = ref.watch(greetingNameProvider);
    return OnboardingHeroScaffold(
      hero: const Padding(
        padding: EdgeInsets.only(top: IqSpace.s2),
        child: Center(
          child: IqIllustration(IqIllustrations.sprout, width: 250),
        ),
      ),
      eyebrow: 'Welcome',
      title: firstName == null
          ? 'Three quick steps'
          : 'Three quick steps, $firstName',
      content: [
        Text(
          'About a minute',
          style: IqText.body.copyWith(color: IqColors.fg2),
        ),
        const Column(
          children: [
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
