import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import 'entry_copy.dart';
import 'entry_state.dart';
import 'entry_widgets.dart';
import 'show_password.dart';

/// B0 Sign in with email (227:11109). A known email from the landing
/// arrives filled in, with the password focused.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  late final EntryInput _email;
  final _password = EntryInput();
  bool _shown = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _email = EntryInput(ref.read(entryDraftProvider).email);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (isEmail(_email.text) ? _password : _email).focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _filled =>
      _email.text.isNotEmpty && _password.controller.text.isNotEmpty;

  Future<void> _next() async {
    if (!_filled || _busy) return;
    if (!isEmail(_email.text)) {
      _email.fail(EntryCopy.badEmail);
      return;
    }
    _busy = true;
    final result = await ref
        .read(authServiceProvider)
        .signIn(email: _email.text, password: _password.controller.text);
    _busy = false;
    if (!mounted) return;
    final failure = result.failure;
    if (failure != null) {
      _password.fail(EntryCopy.signIn(failure));
      return;
    }
    await completeSignIn(ref, newAccount: false);
    if (mounted) context.go(Routes.home);
  }

  void _forgot() {
    ref.read(entryDraftProvider.notifier).setEmail(_email.text);
    context.push(Routes.forgotPassword);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_email.changes, _password.changes]),
      builder: (context, _) => EntryScaffold(
        title: 'Sign in with email',
        onBack: () => goBack(context, Routes.landing),
        action: NextBar(enabled: _filled, onTap: _next),
        children: [
          const EntryTitle('Sign in'),
          const SizedBox(height: IqSpace.s4),
          EntryField(
            input: _email,
            label: 'Email',
            valid: isEmail(_email.text),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _password.focus.requestFocus(),
          ),
          const SizedBox(height: IqSpace.s4),
          EntryField(
            input: _password,
            label: 'Password',
            valid: _password.controller.text.isNotEmpty,
            obscureText: !_shown,
            keyboardType: TextInputType.visiblePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _next(),
          ),
          const SizedBox(height: IqSpace.s4 - EntryLink.linkSlack),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: EntryLink(
                  label: 'Forgot your password?',
                  onTap: _forgot,
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
