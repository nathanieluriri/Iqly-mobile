import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../data/auth.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import 'entry_copy.dart';
import 'entry_state.dart';
import 'entry_widgets.dart';

/// B0 Forgot password (227:11157).
///
/// A bad address or a failed send shows the error banner under the field,
/// as Sign in does (480:19882).
///
/// Motion (MOTION-SPEC 6.7): it pushes in with the back button holding,
/// while the title, body and Email settle 40 apart. Send reset link drops with the commit haptic and turns
/// to a spinner while it sends; then the success haptic and the push to
/// Reset link sent, the keyboard going down with it.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final EntryInput _email;
  late final bool _knownEmail = isEmail(_email.text);
  bool _sending = false;
  String? _failure;

  String _typed = '';

  void _clearFailure() {
    if (_email.controller.text == _typed) return;
    _typed = _email.controller.text;
    if (_failure != null) setState(() => _failure = null);
  }

  void _fail(String message) {
    setState(() => _failure = message);
    errorHaptic();
  }

  @override
  void initState() {
    super.initState();
    _email = EntryInput(ref.read(entryDraftProvider).email);
    _typed = _email.controller.text;
    _email.controller.addListener(_clearFailure);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text;
    if (_sending) return;
    if (email.isEmpty) return _email.nudge();
    if (!isEmail(email)) return _fail(EntryCopy.badEmail);
    setState(() {
      _sending = true;
      _failure = null;
    });
    final result = await ref.read(authServiceProvider).sendResetLink(email);
    if (!mounted) return;
    setState(() => _sending = false);
    final failure = result.failure;
    if (failure != null) return _fail(EntryCopy.resetLink(failure));
    ref.read(entryDraftProvider.notifier).setEmail(email);
    IqHaptics.success.play();
    FocusManager.instance.primaryFocus?.unfocus();
    context.push(Routes.resetLinkSent);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _email.changes,
      builder: (context, _) {
        return EntryScaffold(
          onBack: () => goBack(context, Routes.signIn),
          settle: true,
          action: EntryAction(
            label: 'Send reset link',
            loading: _sending,
            onTap: _send,
          ),
          children: [
            const StaggerItem(
              index: 0,
              child: EntryTitle('Forgot your password?'),
            ),
            const SizedBox(height: IqSpace.s4),
            StaggerItem(
              index: 1,
              child: Text(
                'We’ll email you a link to reset it.',
                style: IqText.body.copyWith(color: IqColors.fg2),
              ),
            ),
            const SizedBox(height: IqSpace.s4),
            StaggerItem(
              index: 2,
              child: EntryField(
                input: _email,
                label: 'Email',
                valid: isEmail(_email.text),
                autofocus: !_knownEmail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
            EntryBanner(message: _failure),
          ],
        );
      },
    );
  }
}
