import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/session.dart';
import '../../data/profile_service.dart';
import '../../router.dart';
import '../../ui/button.dart';
import 'account_closing_screen.dart';

/// B14 · Restore your account? (484:23398): after signing in to an account
/// that is closing (designer answer 18). Restore reopens it and hands off to
/// Discover; Keep it closed signs out to the landing. Sign-in routes here
/// with the closing date when the account says it is closing.
class RestoreAccountScreen extends ConsumerStatefulWidget {
  const RestoreAccountScreen({super.key, this.closesOn});

  final DateTime? closesOn;

  @override
  ConsumerState<RestoreAccountScreen> createState() =>
      _RestoreAccountScreenState();
}

class _RestoreAccountScreenState extends ConsumerState<RestoreAccountScreen> {
  bool _restoring = false;

  Future<void> _restore() async {
    setState(() => _restoring = true);
    await ref.read(profileServiceProvider).restoreAccount();
    if (mounted) context.go(Routes.home);
  }

  Future<void> _keepClosed() async {
    await ref.read(sessionProvider.notifier).setSignedIn(false);
    if (mounted) context.go(Routes.landing);
  }

  @override
  Widget build(BuildContext context) {
    final closesOn = widget.closesOn;
    final when = closesOn == null
        ? 'in 30 days'
        : 'on ${DateFormat('d MMMM').format(closesOn)}';
    return ClosingLayout(
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
