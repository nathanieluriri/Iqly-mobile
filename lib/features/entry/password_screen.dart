import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../data/auth.dart';
import '../../core/transitions.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/icon.dart';
import '../../ui/step_mark.dart';
import 'entry_copy.dart';
import 'entry_state.dart';
import 'entry_widgets.dart';
import 'show_password.dart';

/// B0 Password (227:10970), with the show or hide toggle the brief adds.
///
/// Motion (MOTION-SPEC 6.5): it arrives from Your name with the chrome
/// holding still (the step mark morphs 2 to 3) while the title rides the
/// push and the field trails it by 40 ms; PASSWORD has focus from the first
/// frame. The next button works (a spinner) while the account is made,
/// then the success haptic and the hand-off to Welcome, the keyboard going
/// down with it.
class PasswordScreen extends ConsumerStatefulWidget {
  const PasswordScreen({super.key});

  @override
  ConsumerState<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends ConsumerState<PasswordScreen> {
  final _password = EntryInput();
  bool _shown = false;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final password = _password.controller.text;
    if (password.isEmpty || _busy) return;
    if (password.length < minPasswordLength) {
      _password.fail(ShippedCopy.shortPassword);
      return;
    }
    setState(() => _busy = true);
    final draft = ref.read(entryDraftProvider);
    final result = await ref
        .read(authServiceProvider)
        .signUp(
          firstName: draft.firstName,
          lastName: draft.lastName,
          email: draft.email,
          password: password,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    final failure = result.failure;
    if (failure == AuthFailure.emailTaken) {
      context.go(Routes.signIn);
      return;
    }
    if (failure != null) {
      _password.fail(EntryCopy.signUp(failure));
      return;
    }
    await completeSignIn(ref, newAccount: true);
    if (!mounted) return;
    IqHaptics.success.play();
    FocusManager.instance.primaryFocus?.unfocus();
    context.go(Routes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _password.changes,
      builder: (context, _) => EntryScaffold(
        onBack: () => goBack(context, Routes.yourName),
        action: NextBar(
          enabled: _password.controller.text.isNotEmpty,
          loading: _busy,
          onTap: _next,
        ),
        children: [
          const EntryStepMark(
            step: IqStepMarkStep.threeOfThree,
            icon: IqIcons.lock,
          ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
