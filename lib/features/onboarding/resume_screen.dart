import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/illustration.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';

/// B11 · Resume (188:8443): what the app opens on when first run was left
/// mid-flow.
class ResumeScreen extends ConsumerWidget {
  const ResumeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next =
        ref.watch(onboardingDraftProvider.select((d) => d.lastStep)) ??
        OnboardingStep.aboutYou;
    return OnboardingHeroScaffold(
      hero: const Padding(
        padding: EdgeInsets.only(top: IqSpace.s2),
        child: Center(child: IqIllustration(IqIllustrations.pin)),
      ),
      eyebrow: 'Welcome back',
      title: 'Pick up where you left off',
      content: [
        Text(
          'Next: ${next.label}',
          style: IqText.body.copyWith(color: IqColors.fg2),
        ),
      ],
      actions: [
        IqButton(
          label: 'Continue',
          showIcon: false,
          width: double.infinity,
          onTap: () => goToStep(context, ref, next),
        ),
        IqButton(
          label: 'Start over',
          kind: IqButtonKind.ghost,
          showIcon: false,
          width: double.infinity,
          onTap: () {
            ref.read(onboardingDraftProvider.notifier).startOver();
            context.go(Routes.onboardingAboutYou);
          },
        ),
      ],
    );
  }
}
