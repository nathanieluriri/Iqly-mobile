import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/illustration.dart';
import '../entry/entry_state.dart';

/// B14 · Account closing (225:10830), the interstitial after Delete my
/// account, signed out, reached by a 300 ms hand-off. Calm: the Megaphone
/// arrives (fade and rise 16 over 320, no accent beat), the title and body
/// appear at +80 and +120, the buttons come with the page (spec 7.10). Done
/// hands off to the landing; "Changed your mind? Sign in" opens Sign in
/// with the email filled.
///
/// Figma over brief: the frame uses Exp/Illustration Megaphone with a
/// Primary and a Ghost Exp/Button, where the brief names the Thinker figure
/// and Exp/BarButton.
class AccountClosingScreen extends ConsumerWidget {
  const AccountClosingScreen({super.key, this.email});

  /// The closed account's email, so Sign in arrives filled.
  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void signIn() {
      final email = this.email;
      if (email != null) ref.read(entryDraftProvider.notifier).setEmail(email);
      context.go(Routes.signIn);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      IqSpace.s4,
                      IqSpace.s12,
                      IqSpace.s4,
                      IqSpace.s4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(
                          height: 176,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Arrive(
                              distance: IqTravel.riseHero,
                              duration: IqDurations.morph,
                              child: IqIllustration(IqIllustrations.megaphone),
                            ),
                          ),
                        ),
                        const SizedBox(height: IqSpace.s3),
                        Appear(
                          delay: IqDurations.stagger * 2,
                          child: Text(
                            'Your account is closing',
                            style: IqText.display.copyWith(color: IqColors.fg),
                          ),
                        ),
                        const SizedBox(height: IqSpace.s3),
                        Appear(
                          delay: IqDurations.stagger * 3,
                          child: Text(
                            'Sign in within 30 days to undo.',
                            style: IqText.body.copyWith(color: IqColors.fg2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    IqSpace.s3,
                    IqSpace.s4,
                    IqSpace.s3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IqButton(
                        label: 'Done',
                        showIcon: false,
                        width: double.infinity,
                        onTap: () => context.go(Routes.landing),
                      ),
                      const SizedBox(height: IqSpace.s2),
                      IqButton(
                        label: 'Changed your mind? Sign in',
                        kind: IqButtonKind.ghost,
                        showIcon: false,
                        width: double.infinity,
                        onTap: signIn,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
