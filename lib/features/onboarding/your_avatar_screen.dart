import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../router.dart';
import '../../ui/avatar.dart';
import '../avatar/avatar_state.dart';
import '../avatar/avatar_step.dart';
import 'onboarding_layout.dart';

/// B22 · Onboarding · Your avatar (582:28894), the optional step after What
/// you like: the avatar a new account starts with. Make it mine opens the
/// editor, which comes back here; Looks good, continue lands the onboarding
/// on Done.
class YourAvatarScreen extends ConsumerWidget {
  const YourAvatarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = ref.watch(avatarProvider.select((a) => a.spec));
    return AvatarStepScaffold(
      title: 'Your avatar',
      heading: 'Meet your avatar',
      caption:
          'We made one to start. Make it look like you now, or later from '
          'More.',
      onBack: () => leaveStep(context, Routes.onboardingWhatYouLike),
      centre: IqAvatar(avatar),
      primary: 'Make it mine',
      onPrimary: () => context.push(Routes.avatarEditor),
      ghost: 'Looks good, continue',
      onGhost: () {
        IqHaptics.success.play();
        context.go(Routes.onboardingDone);
      },
    );
  }
}
