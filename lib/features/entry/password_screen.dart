import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/icon.dart';
import '../../ui/step_mark.dart';
import 'entry_copy.dart';
import 'entry_state.dart';
import 'entry_widgets.dart';
import 'show_password.dart';

/// B0 Password (227:10970), with the show or hide toggle the brief adds.
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _password.focus.requestFocus();
    });
  }

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
    _busy = true;
    final draft = ref.read(entryDraftProvider);
    final result = await ref
        .read(authServiceProvider)
        .signUp(
          firstName: draft.firstName,
          lastName: draft.lastName,
          email: draft.email,
          password: password,
        );
    _busy = false;
    if (!mounted) return;
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
    if (mounted) context.go(Routes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _password.changes,
      builder: (context, _) => EntryScaffold(
        onBack: () => goBack(context, Routes.yourName),
        action: NextBar(
          enabled: _password.controller.text.isNotEmpty,
          onTap: _next,
        ),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: IqStepMark(
              step: IqStepMarkStep.threeOfThree,
              icon: IqIcons.lock,
            ),
          ),
          const SizedBox(height: IqSpace.s4),
          const EntryTitle('Create a password'),
          const SizedBox(height: IqSpace.s4),
          EntryField(
            input: _password,
            label: 'Password',
            valid: _password.controller.text.length >= minPasswordLength,
            obscureText: !_shown,
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
    );
  }
}
