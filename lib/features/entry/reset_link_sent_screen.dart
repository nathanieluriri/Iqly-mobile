import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../data/auth.dart';
import '../../data/device.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/illustration.dart';
import 'entry_state.dart';
import 'entry_widgets.dart';

/// B0 Reset link sent (227:11209), a moment. Figma hides the bar's back
/// button here; "Remembered? Sign in" and the system back lead out.
///
/// Motion (MOTION-SPEC 6.8): the success haptic plays as it is pushed; the
/// Reach figure rises in 16 (320 ms), the title appears at +80, "Sent to" at
/// +120 and "Remembered? Sign in" at +160, the buttons come with the page.
/// Resend link spins, then the "Sent to" line rolls once and the success
/// haptic plays. "Sign in" pops back to Sign in, only this page moving.
class ResetLinkSentScreen extends ConsumerStatefulWidget {
  const ResetLinkSentScreen({super.key});

  @override
  ConsumerState<ResetLinkSentScreen> createState() =>
      _ResetLinkSentScreenState();
}

class _ResetLinkSentScreenState extends ConsumerState<ResetLinkSentScreen> {
  bool _opening = false;
  bool _resending = false;
  int _sent = 0;

  Future<void> _openEmail() async {
    if (_opening) return;
    setState(() => _opening = true);
    await ref.read(deviceServiceProvider).openEmailApp();
    if (mounted) setState(() => _opening = false);
  }

  Future<void> _resend(String email) async {
    if (_resending) return;
    setState(() => _resending = true);
    final result = await ref.read(authServiceProvider).sendResetLink(email);
    if (!mounted) return;
    final ok = result.failure == null;
    setState(() {
      _resending = false;
      if (ok) _sent++;
    });
    if (ok) IqHaptics.success.play();
  }

  /// Back to Sign in with email under Forgot password: both pages leave
  /// the stack in one change, so Forgot goes at once and only this page
  /// pops. From anywhere else, Sign in takes over.
  void _signIn() {
    final router = GoRouter.of(context);
    final stack = router.routerDelegate.currentConfiguration;
    final matches = stack.matches;
    final n = matches.length;
    String? path(int i) => switch (matches[i].route) {
      GoRoute(:final path) => path,
      _ => null,
    };
    if (n >= 3 &&
        path(n - 1) == Routes.resetLinkSent &&
        path(n - 2) == Routes.forgotPassword &&
        path(n - 3) == Routes.signIn) {
      router.restore(stack.remove(matches[n - 1]).remove(matches[n - 2]));
    } else {
      router.go(Routes.signIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(entryDraftProvider.select((d) => d.email));
    return EntryScaffold(
      hasFields: false,
      entrance: IqMomentTiming.bodyAt + IqDurations.appear,
      showBack: false,
      onBack: () => goBack(context, Routes.forgotPassword),
      action: EntryButtons(
        primary: 'Open email app',
        onPrimary: _openEmail,
        primaryLoading: _opening,
        ghost: 'Resend link',
        onGhost: () => _resend(email),
        ghostLoading: _resending,
      ),
      children: [
        const Beat(
          move: BeatMove.rise,
          child: Align(
            alignment: Alignment.centerLeft,
            child: IqFigure(IqFigures.reach, width: 169.41),
          ),
        ),
        const SizedBox(height: IqSpace.s4),
        const Beat(
          at: IqMomentTiming.eyebrowAt,
          child: EntryTitle('Check your email'),
        ),
        const SizedBox(height: IqSpace.s4),
        Beat(
          at: IqMomentTiming.titleAt,
          child: _Reroll(
            turn: _sent,
            child: Text(
              'Sent to $email',
              style: IqText.body.copyWith(color: IqColors.fg2),
            ),
          ),
        ),
        const SizedBox(height: IqSpace.s4 - EntryLink.linkSlack),
        Beat(
          at: IqMomentTiming.bodyAt,
          child: LinkRow(
            lead: 'Remembered?',
            link: 'Sign in',
            alignment: MainAxisAlignment.start,
            onTap: _signIn,
          ),
        ),
      ],
    );
  }
}

/// Rolls [child] once each time [turn] changes, the same words leaving up 6
/// as they come back in from +6, 160 ms ease-out (spec 2.5 roll); a cut
/// under reduced motion.
class _Reroll extends StatelessWidget {
  const _Reroll({required this.turn, required this.child});

  final int turn;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motion(context, IqDurations.tick),
      switchInCurve: IqCurves.easeOut,
      switchOutCurve: IqCurves.easeOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final leaving = animation.status == AnimationStatus.reverse;
          final travel = IqTravel.tick * (1 - animation.value);
          return Opacity(
            opacity: animation.value,
            child: Transform.translate(
              offset: Offset(0, leaving ? -travel : travel),
              child: child,
            ),
          );
        },
      ),
      child: KeyedSubtree(key: ValueKey(turn), child: child),
    );
  }
}
