import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../data/auth.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import 'entry_copy.dart';
import 'entry_state.dart';
import 'entry_widgets.dart';

/// B0 Verify email (1268:25917 and its five states): the 6-digit code
/// emailed after Create account, or after signing in before verifying.
///
/// Verify email stays off until six digits are in, and the sixth digit
/// submits on its own. A wrong code keeps the code to edit; an expired code
/// or too many tries turns the button off until a new code is sent. A new
/// code can go out once a minute.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  static const codeLength = 6;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = EntryInput();
  late final String _email = ref.read(entryDraftProvider).email;
  Timer? _tick;
  Duration _left = AuthTiming.codeResendAfter;
  bool _resent = false;
  bool _busy = false;
  bool _sending = false;
  AuthFailure? _failure;
  String _typed = '';

  /// The code on screen can't work any more: only a new one will do.
  bool get _spent =>
      _failure == AuthFailure.codeExpired ||
      _failure == AuthFailure.tooManyAttempts;

  bool get _complete => _code.text.length == VerifyEmailScreen.codeLength;

  @override
  void initState() {
    super.initState();
    _code.controller.addListener(_edited);
    _countDown();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _countDown() {
    _tick?.cancel();
    _left = AuthTiming.codeResendAfter;
    _tick = Timer.periodic(AuthTiming.countdownStep, (timer) {
      if (!mounted) return;
      setState(() => _left -= AuthTiming.countdownStep);
      if (_left <= Duration.zero) timer.cancel();
    });
  }

  void _edited() {
    if (_code.controller.text == _typed) return;
    _typed = _code.controller.text;
    if (_failure != null && !_spent) setState(() => _failure = null);
    if (_complete && !_spent) _verify();
  }

  Future<void> _verify() async {
    if (_busy || _spent || !_complete) return;
    setState(() => _busy = true);
    final result = await ref
        .read(authServiceProvider)
        .verifyEmail(email: _email, code: _code.text);
    if (!mounted) return;
    final failure = result.failure;
    if (failure != null) {
      setState(() {
        _busy = false;
        _failure = failure;
      });
      errorHaptic();
      return;
    }
    final next = await completeSignIn(
      ref,
      newAccount: result.newAccount,
      name: result.name,
      userId: result.userId,
    );
    if (!mounted) return;
    IqHaptics.success.play();
    FocusManager.instance.primaryFocus?.unfocus();
    context.go(next.route, extra: next.extra);
  }

  Future<void> _sendNew() async {
    if (_sending) return;
    setState(() => _sending = true);
    final result = await ref
        .read(authServiceProvider)
        .sendVerificationCode(_email);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _failure = result.failure;
      if (result.ok) {
        _resent = true;
        _typed = '';
        _code.controller.clear();
        _code.focus.requestFocus();
        _countDown();
      }
    });
    if (!result.ok) errorHaptic();
  }

  String get _clock =>
      '${_left.inMinutes}:${(_left.inSeconds % 60).toString().padLeft(2, '0')}';

  bool get _counting => _left > Duration.zero && !_spent;

  Widget _resendRow() {
    if (_counting) {
      return Text(
        _resent
            ? 'New code sent. You can send another in $_clock.'
            : 'Didn’t get it? Send a new code in $_clock',
        style: IqText.small.copyWith(color: IqColors.fg2),
      );
    }
    return LinkRow(
      lead: _spent ? 'Need a new one?' : 'Didn’t get it?',
      link: 'Send a new code',
      alignment: MainAxisAlignment.start,
      onTap: _sendNew,
    );
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    return ListenableBuilder(
      listenable: _code.changes,
      builder: (context, _) => EntryScaffold(
        onBack: () => goBack(context, Routes.signIn),
        settle: true,
        action: EntryAction(
          label: 'Verify email',
          loading: _busy,
          disabled: !_complete || _spent,
          onTap: _verify,
        ),
        children: [
          const StaggerItem(index: 0, child: EntryTitle('Check your email')),
          const SizedBox(height: IqSpace.s4),
          StaggerItem(
            index: 1,
            child: Text(
              'We sent a 6-digit code to $_email. It expires in 5 minutes.',
              style: IqText.body.copyWith(color: IqColors.fg2),
            ),
          ),
          const SizedBox(height: IqSpace.s4),
          StaggerItem(
            index: 2,
            child: EntryField(
              input: _code,
              label: '6-digit code',
              rejected: failure != null && failure != AuthFailure.offline,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(VerifyEmailScreen.codeLength),
              ],
              onSubmitted: (_) => _verify(),
            ),
          ),
          EntryBanner(
            message: failure == null ? null : EntryCopy.code(failure),
          ),
          SizedBox(
            height: _counting ? IqSpace.s4 : IqSpace.s4 - EntryLink.linkSlack,
          ),
          StaggerItem(index: 3, child: _resendRow()),
        ],
      ),
    );
  }
}
