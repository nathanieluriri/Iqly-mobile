import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/backend.dart';
import '../../core/motion.dart';
import '../../data/auth.dart';
import '../../data/live/live_account.dart';
import '../../data/profile_service.dart';
import '../../router.dart';
import '../../ui/button.dart';
import '../profile/profile_state.dart';
import 'account_closing_screen.dart';

/// The closing state for a write the API refused as ACCOUNT_CLOSING:
/// Restore, with the close date `GET /me` reports when it answers in time.
Future<void> showClosingAccount(BuildContext context, WidgetRef ref) async {
  DateTime? closesOn;
  try {
    closesOn =
        (await ref.refresh(meProvider.future).timeout(AuthTiming.closingCheck))
            ?.closesAt;
  } on Exception {
    closesOn = null;
  }
  if (context.mounted) context.go(Routes.restoreAccount, extra: closesOn);
}

/// B14 · Restore your account? (484:23398): after signing in to an account
/// that is closing (designer answer 18). Restore reopens it and hands off to
/// Discover; Keep it closed signs out to the landing. Sign-in, and a launch
/// signed in, route here with the closing date when the account says it is
/// closing. A restore that does not go through stops loading, plays the
/// error haptic and slides in the error banner (the frame has no failed
/// state; the words are the app's for a send that did not go through).
///
/// A launch that pauses the account still lands here: the account is
/// closing, the API refuses its writes, and Keep it closed still signs out.
/// Restore then refuses before anything is sent, under the banner's first
/// sentence only, since no connection is at fault (no frame for it).
class RestoreAccountScreen extends ConsumerStatefulWidget {
  const RestoreAccountScreen({super.key, this.closesOn});

  final DateTime? closesOn;

  @override
  ConsumerState<RestoreAccountScreen> createState() =>
      _RestoreAccountScreenState();
}

class _RestoreAccountScreenState extends ConsumerState<RestoreAccountScreen> {
  bool _restoring = false;
  bool _failed = false;
  bool _paused = false;
  bool _leaving = false;

  Future<void> _restore() async {
    if (_restoring || _leaving) return;
    setState(() {
      _restoring = true;
      _failed = false;
    });
    try {
      await ref.read(profileServiceProvider).restoreAccount();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _failed = true;
        _paused = error is FeaturePaused;
      });
      errorHaptic();
      return;
    }
    if (mounted) context.go(Routes.home);
  }

  Future<void> _keepClosed() async {
    if (_restoring || _leaving) return;
    setState(() => _leaving = true);
    await forgetAccount(ref, closed: true);
    if (mounted) context.go(Routes.landing);
  }

  @override
  Widget build(BuildContext context) {
    final closesOn = widget.closesOn;
    final when = closesOn == null
        ? 'in 30 days'
        : 'on ${DateFormat('d MMMM').format(closesOn)}';
    return ClosingLayout(
      failed: _failed,
      failedTitle: _paused ? 'Couldn’t send.' : ClosingLayout.failedText,
      title: 'Welcome back. Restore your account?',
      body:
          'Your account closes $when. Sign in now and everything stays: '
          'wallet, submissions and history.',
      primary: IqButton(
        label: 'Restore my account',
        showIcon: false,
        width: double.infinity,
        loading: _restoring,
        onTap: _restore,
      ),
      ghost: IqButton(
        label: 'Keep it closed',
        kind: IqButtonKind.ghost,
        showIcon: false,
        width: double.infinity,
        onTap: _keepClosed,
      ),
    );
  }
}
