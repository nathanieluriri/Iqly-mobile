import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/field.dart';
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = EntryInput(ref.read(entryDraftProvider).email);
    _password.controller.addListener(_clearError);
    _email.controller.addListener(_clearError);
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

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  bool get _ready =>
      isEmail(_email.text) && _password.controller.text.isNotEmpty;

  Future<void> _next() async {
    if (!_ready || _busy) return;
    _busy = true;
    final result = await ref
        .read(authServiceProvider)
        .signIn(email: _email.text, password: _password.controller.text);
    _busy = false;
    if (!mounted) return;
    if (!result.ok) {
      setState(() => _error = result.error);
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
        action: NextBar(enabled: _ready, onTap: _next),
        children: [
          const EntryTitle('Sign in'),
          const SizedBox(height: IqSpace.s4),
          IqField(
            size: IqFieldSize.large,
            label: 'Email',
            value: '',
            state: fieldStateFor(_email, valid: isEmail(_email.text)),
            showStatus: false,
            showNote: false,
            controller: _email.controller,
            focusNode: _email.focus,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _password.focus.requestFocus(),
          ),
          const SizedBox(height: IqSpace.s4),
          IqField(
            size: IqFieldSize.large,
            label: 'Password',
            value: '',
            help: _error ?? '',
            state: fieldStateFor(
              _password,
              valid: _password.controller.text.isNotEmpty,
              error: _error != null,
            ),
            showStatus: false,
            showNote: false,
            controller: _password.controller,
            focusNode: _password.focus,
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
