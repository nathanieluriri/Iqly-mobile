import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../data/auth.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import 'entry_copy.dart';
import 'entry_state.dart';
import 'entry_widgets.dart';
import 'show_password.dart';

/// B0 Sign in with email (227:11109). A known email from the landing
/// arrives filled in, with the password focused. A failed sign in shows the
/// error banner under the fields (480:19882), gone as soon as either field
/// changes; the owner's Show / Hide toggle sits on the forgot row.
///
/// Motion (MOTION-SPEC 6.6): it pushes in as the title, EMAIL, PASSWORD and
/// "Forgot your password?" settle 40 apart, the right field focused from
/// the first frame. The next button works (a spinner) while signing in;
/// success hands off to Discover with the keyboard going down. An email not
/// verified yet gets a code and goes on to Verify email.
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
  String? _failure;

  @override
  void initState() {
    super.initState();
    _email = EntryInput(ref.read(entryDraftProvider).email);
    _knownEmail = isEmail(_email.text);
    _typed = '${_email.controller.text}\n';
    _email.controller.addListener(_clearFailure);
    _password.controller.addListener(_clearFailure);
  }

  String _typed = '';

  void _clearFailure() {
    final typed = '${_email.controller.text}\n${_password.controller.text}';
    if (typed == _typed) return;
    _typed = typed;
    if (_failure != null) setState(() => _failure = null);
  }

  void _fail(String message) {
    setState(() => _failure = message);
    errorHaptic();
  }

  late final bool _knownEmail;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_busy) return;
    if (_email.text.isEmpty) return _email.nudge();
    if (_password.controller.text.isEmpty) return _password.nudge();
    if (!isEmail(_email.text)) return _fail(EntryCopy.badEmail);
    setState(() {
      _busy = true;
      _failure = null;
    });
    final result = await ref
        .read(authServiceProvider)
        .signIn(email: _email.text, password: _password.controller.text);
    if (!mounted) return;
    final failure = result.failure;
    if (failure == AuthFailure.emailNotVerified) return _verifyFirst();
    if (failure != null) {
      setState(() => _busy = false);
      return _fail(EntryCopy.signIn(failure));
    }
    final next = await completeSignIn(
      ref,
      newAccount: result.newAccount,
      name: result.name,
      userId: result.userId,
    );
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    context.go(next.route, extra: next.extra);
  }

  /// The account exists but its email isn't confirmed yet: send a code and
  /// finish on Verify email.
  Future<void> _verifyFirst() async {
    final sent = await ref
        .read(authServiceProvider)
        .sendVerificationCode(_email.text);
    if (!mounted) return;
    setState(() => _busy = false);
    final failure = sent.failure;
    if (failure != null) return _fail(EntryCopy.signIn(failure));
    ref.read(entryDraftProvider.notifier).setEmail(_email.text);
    FocusManager.instance.primaryFocus?.unfocus();
    context.open(Routes.verifyEmail);
  }

  void _forgot() {
    ref.read(entryDraftProvider.notifier).setEmail(_email.text);
    context.open(Routes.forgotPassword);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_email.changes, _password.changes]),
      builder: (context, _) => EntryScaffold(
        onBack: () => goBack(context, Routes.landing),
        settle: true,
        action: EntryAction(label: 'Sign in', loading: _busy, onTap: _next),
        children: [
          const StaggerItem(index: 0, child: EntryTitle('Sign in')),
          const SizedBox(height: IqSpace.s4),
          StaggerItem(
            index: 1,
            child: EntryField(
              input: _email,
              label: 'Email',
              valid: isEmail(_email.text),
              autofocus: !_knownEmail,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _password.focus.requestFocus(),
            ),
          ),
          const SizedBox(height: IqSpace.s4),
          StaggerItem(
            index: 2,
            child: EntryField(
              input: _password,
              label: 'Password',
              valid: _password.controller.text.isNotEmpty,
              obscureText: !_shown,
              autofocus: _knownEmail,
              keyboardType: TextInputType.visiblePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _next(),
            ),
          ),
          EntryBanner(message: _failure),
          const SizedBox(height: IqSpace.s4 - EntryLink.linkSlack),
          StaggerItem(
            index: 3,
            child: Row(
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
          ),
        ],
      ),
    );
  }
}
