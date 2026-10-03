import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth.dart';
import '../../data/device.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/icon.dart';
import 'entry_state.dart';
import 'entry_widgets.dart';

/// B0 Reset link sent (227:11209).
class ResetLinkSentScreen extends ConsumerStatefulWidget {
  const ResetLinkSentScreen({super.key});

  @override
  ConsumerState<ResetLinkSentScreen> createState() =>
      _ResetLinkSentScreenState();
}

class _ResetLinkSentScreenState extends ConsumerState<ResetLinkSentScreen> {
  bool _opening = false;
  bool _resending = false;

  Future<void> _openEmail() async {
    if (_opening) return;
    setState(() => _opening = true);
    await ref.read(deviceServiceProvider).openEmailApp();
    if (mounted) setState(() => _opening = false);
  }

  Future<void> _resend(String email) async {
    if (_resending) return;
    setState(() => _resending = true);
    await ref.read(authServiceProvider).sendResetLink(email);
    if (mounted) setState(() => _resending = false);
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(entryDraftProvider.select((d) => d.email));
    return EntryScaffold(
      hasFields: false,
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
        const SizedBox(
          height: 88,
          child: Align(
            alignment: Alignment.centerLeft,
            child: IqIcon(IqIcons.mail, size: 72, color: IqColors.brand),
          ),
        ),
        const SizedBox(height: IqSpace.s4),
        const EntryTitle('Check your email'),
        const SizedBox(height: IqSpace.s4),
        Text(
          'Sent to $email',
          style: IqText.body.copyWith(color: IqColors.fg2),
        ),
        const SizedBox(height: IqSpace.s4 - EntryLink.linkSlack),
        LinkRow(
          lead: 'Remembered?',
          link: 'Sign in',
          alignment: MainAxisAlignment.start,
          onTap: () => context.go(Routes.signIn),
        ),
      ],
    );
  }
}
