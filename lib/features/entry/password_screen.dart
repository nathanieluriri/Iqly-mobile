import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/transitions.dart';
import '../../data/auth.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/step_mark.dart';
import 'entry_copy.dart';
import 'entry_state.dart';
import 'entry_widgets.dart';
import 'show_password.dart';

/// B0 Password (227:10970), with the show or hide toggle the owner adds on
/// the caption row. A short password gets the shipped words under the
/// field; a failed call gets the error banner (answer 10).
///
/// Motion (MOTION-SPEC 6.5): it arrives from Your name with the chrome
/// holding still (the step mark fills its third bar) while the title rides
/// the push and the field trails it by 40 ms; Password has focus from the
/// first frame. Create account works (a spinner) while the account is made,
/// then the success haptic and the push to Verify email, which emails the
/// code that finishes sign up.
class PasswordScreen extends ConsumerStatefulWidget {
  const PasswordScreen({super.key});

  @override
  ConsumerState<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends ConsumerState<PasswordScreen> {
  final _password = EntryInput();
  bool _shown = false;
  bool _busy = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _password.controller.addListener(_clearFailure);
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _clearFailure() {
    if (_failure != null) setState(() => _failure = null);
  }

  Future<void> _next() async {
    final password = _password.controller.text;
    if (_busy) return;
    if (password.isEmpty) return _password.nudge();
    if (password.length < minPasswordLength) {
      _password.fail(ShippedCopy.shortPassword);
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    final draft = ref.read(entryDraftProvider);
    final result = await ref
        .read(authServiceProvider)
        .signUp(
          firstName: draft.firstName,
          lastName: draft.lastName,
          email: draft.email,
          password: password,
          inviteCode: ref.read(pendingInviteProvider)?.code,
        );
    if (!mounted) return;
    final failure = result.failure;
    if (failure != null) setState(() => _busy = false);
    if (failure == AuthFailure.emailTaken) {
      context.go(Routes.signIn);
      return;
    }
    if (failure != null) {
      setState(() => _failure = EntryCopy.signUp(failure));
      errorHaptic();
      return;
    }
    setState(() => _busy = false);
    IqHaptics.success.play();
    FocusManager.instance.primaryFocus?.unfocus();
    context.push(Routes.verifyEmail);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _password.changes,
      builder: (context, _) => EntryScaffold(
        onBack: () => goBack(context, Routes.yourName),
        action: EntryAction(
          label: 'Create account',
          loading: _busy,
          onTap: _next,
        ),
        children: [
          const StepMarkChrome(step: IqStepMarkStep.threeOfThree),
          const SizedBox(height: IqSpace.s4),
          const EntryTitle('Create a password'),
          const SizedBox(height: IqSpace.s4),
          PushTrail(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EntryField(
                  input: _password,
                  label: 'Password',
                  valid: _password.controller.text.length >= minPasswordLength,
                  obscureText: !_shown,
                  autofocus: true,
                  keyboardType: TextInputType.visiblePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _next(),
                ),
                const SizedBox(height: IqSpace.s4 - EntryLink.linkSlack),
                Row(
                  children: [
                    Expanded(
                      child: _password.error == ShippedCopy.shortPassword
                          ? const SizedBox.shrink()
                          : Text(
                              ShippedCopy.shortPassword,
                              style: IqText.small.copyWith(color: IqColors.fg2),
                            ),
                    ),
                    ShowPassword(
                      shown: _shown,
                      onTap: () => setState(() => _shown = !_shown),
                    ),
                  ],
                ),
                EntryBanner(message: _failure),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
