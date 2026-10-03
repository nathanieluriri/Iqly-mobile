import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../data/auth.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import 'entry_copy.dart';
import 'entry_state.dart';
import 'entry_widgets.dart';

/// B0 Forgot password (227:11157).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final EntryInput _email;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _email = EntryInput(ref.read(entryDraftProvider).email);
    if (!isEmail(_email.text)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _email.focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text;
    if (email.isEmpty || _sending) return;
    if (!isEmail(email)) {
      _email.fail(EntryCopy.badEmail);
      return;
    }
    setState(() => _sending = true);
    final result = await ref.read(authServiceProvider).sendResetLink(email);
    if (!mounted) return;
    setState(() => _sending = false);
    final failure = result.failure;
    if (failure != null) {
      _email.fail(EntryCopy.resetLink(failure));
      return;
    }
    ref.read(entryDraftProvider.notifier).setEmail(email);
    IqHaptics.success.play();
    context.push(Routes.resetLinkSent);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _email.changes,
      builder: (context, _) {
        return EntryScaffold(
          onBack: () => goBack(context, Routes.signIn),
          action: Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s4,
              IqSpace.s3,
              IqSpace.s4,
              IqSpace.s3 + IqButton.height + IqSpace.s2,
            ),
            child: IqButton(
              label: 'Send reset link',
              showIcon: false,
              width: double.infinity,
              disabled: _email.text.isEmpty,
              loading: _sending,
              onTap: _send,
            ),
          ),
          children: [
            const EntryTitle('Forgot your password?'),
            const SizedBox(height: IqSpace.s4),
            Text(
              'We’ll email you a link to reset it.',
              style: IqText.body.copyWith(color: IqColors.fg2),
            ),
            const SizedBox(height: IqSpace.s4),
            EntryField(
              input: _email,
              label: 'Email',
              valid: isEmail(_email.text),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ],
        );
      },
    );
  }
}
