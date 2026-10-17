import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/illustration.dart';
import '../entry/entry_state.dart';

/// B14 · Account closing (225:10830), the interstitial after Delete my
/// account, signed out, reached by a 300 ms hand-off. Calm: the Caller
/// figure arrives (fade and rise 16 over 320), the title and body appear at
/// +80 and +120, the buttons come with the page (spec 7.10). Done hands off
/// to the landing; "Changed your mind? Sign in" opens Sign in with the
/// email filled.
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

    return ClosingLayout(
      title: 'Your account is closing',
      body: 'Sign in within 30 days to undo.',
      primary: IqButton(
        label: 'Done',
        showIcon: false,
        width: double.infinity,
        onTap: () => context.go(Routes.landing),
      ),
      ghost: IqButton(
        label: 'Changed your mind? Sign in',
        kind: IqButtonKind.ghost,
        showIcon: false,
        width: double.infinity,
        onTap: signIn,
      ),
    );
  }
}

/// The Account closing and Restore layout: the Caller figure, a display
/// title and a line, centred around the middle of the screen, over a
/// Primary and a Ghost button. [failed] slides the error banner in at the
/// top, saying [failedTitle].
class ClosingLayout extends StatelessWidget {
  const ClosingLayout({
    super.key,
    required this.title,
    required this.body,
    required this.primary,
    required this.ghost,
    this.failed = false,
    this.failedTitle = failedText,
  });

  final String title;
  final String body;
  final Widget primary;
  final Widget ghost;
  final bool failed;
  final String failedTitle;

  /// The app's words when an action does not go through.
  static const failedText = 'Couldn’t send. Check your connection.';

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
                  child: IqBanner(
                    kind: IqBannerKind.error,
                    title: failedTitle,
                    showAction: false,
                    visible: failed,
                    margin: const EdgeInsets.only(top: IqSpace.s3),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        IqSpace.s4,
                        IqSpace.s8,
                        IqSpace.s4,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(
                            height: 216,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Arrive.illustration(
                                child: IqFigure(IqFigures.caller, width: 188),
                              ),
                            ),
                          ),
                          const SizedBox(height: IqSpace.s3),
                          Appear(
                            delay: IqDurations.stagger * 2,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: IqText.display.copyWith(
                                color: IqColors.fg,
                              ),
                            ),
                          ),
                          const SizedBox(height: IqSpace.s3),
                          Appear(
                            delay: IqDurations.stagger * 3,
                            child: Text(
                              body,
                              textAlign: TextAlign.center,
                              style: IqText.body.copyWith(color: IqColors.fg2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    IqSpace.s3,
                    IqSpace.s4,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      primary,
                      const SizedBox(height: IqSpace.s2),
                      SizedBox(height: 44, child: ghost),
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
