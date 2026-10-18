import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../data/pin_service.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../entry/entry_widgets.dart' show EntryInput;
import '../more/more_widgets.dart';

enum PinStep { create, change, reset }

/// The reset from More, over More itself: the sheets that asked for the
/// PIN close, so none of them keeps the keyboard.
void openPinReset(GoRouter router) {
  router
    ..go(Routes.more)
    ..push(Routes.withdrawalPinReset);
}

/// "Wrong PIN, 3 tries left."
String pinTriesLeft(int? left) => left == null
    ? 'Wrong PIN.'
    : 'Wrong PIN, $left ${left == 1 ? 'try' : 'tries'} left.';

/// "Try again in 30 min" from the lock's Retry-After or its end.
String pinLockWait(Duration? retryAfter, DateTime? until, DateTime now) {
  final wait =
      retryAfter ?? until?.difference(now) ?? const Duration(minutes: 30);
  final minutes = (wait.inSeconds / 60).ceil().clamp(1, 1440);
  return 'Try again in $minutes min';
}

/// The iQLY PIN from More (contract 13.1): set the first one with a code
/// emailed to the account or its password, change it with the current
/// one, or reset it with an emailed code ("Forgot it? Reset it by email
/// from More."), which also lifts a lock. Built from Exp/Field, the buttons
/// and the banner, as PinSheet is: no frame draws these pages. The PINs
/// typed live in the fields only and go in the request body.
class WithdrawalPinScreen extends ConsumerStatefulWidget {
  const WithdrawalPinScreen({super.key, this.reset = false});

  /// Opens on the reset, as a locked PIN asks.
  final bool reset;

  @override
  ConsumerState<WithdrawalPinScreen> createState() =>
      _WithdrawalPinScreenState();
}

class _WithdrawalPinScreenState extends ConsumerState<WithdrawalPinScreen> {
  final _current = EntryInput();
  final _pin = EntryInput();
  final _again = EntryInput();
  final _code = EntryInput();
  final _password = EntryInput();
  PinStep? _step;
  bool _usePassword = false;
  bool _saving = false;
  bool _sending = false;
  String? _banner;
  bool _bannerResets = false;
  String? _sentTo;
  Duration _wait = Duration.zero;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (widget.reset) _step = PinStep.reset;
  }

  @override
  void dispose() {
    _tick?.cancel();
    for (final input in [_current, _pin, _again, _code, _password]) {
      input.dispose();
    }
    super.dispose();
  }

  PinStep _stepFor(PinStatus? status) =>
      _step ??
      switch (status) {
        PinStatus(set: false) => PinStep.create,
        PinStatus(resetRequired: true) => PinStep.reset,
        _ => PinStep.change,
      };

  void _go(PinStep step, {String? banner, bool resets = false}) {
    setState(() {
      _step = step;
      _banner = banner;
      _bannerResets = resets;
      for (final input in [_current, _pin, _again, _code, _password]) {
        input.controller.clear();
      }
    });
  }

  Duration _left() => _wait;

  /// Counts the resend down a second at a time from [wait].
  void _countDown(Duration? wait) {
    _tick?.cancel();
    final left = wait == null || wait.isNegative ? Duration.zero : wait;
    setState(() => _wait = left);
    if (left == Duration.zero) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _wait -= const Duration(seconds: 1));
      if (_wait <= Duration.zero) timer.cancel();
    });
  }

  Future<void> _sendCode() async {
    final pins = ref.read(pinServiceProvider);
    if (pins == null || _sending || _left() > Duration.zero) return;
    setState(() {
      _sending = true;
      _banner = null;
    });
    try {
      final sent = await pins.sendCode();
      if (!mounted) return;
      setState(() => _sentTo = sent.sentTo);
      _countDown(
        sent.resendAt?.difference(ref.read(clockProvider)()) ??
            const Duration(seconds: 60),
      );
    } on PinRefused catch (refused) {
      if (!mounted) return;
      if (refused.problem == PinProblem.rateLimited) {
        _countDown(refused.retryAfter ?? const Duration(seconds: 60));
      } else {
        _refused(refused);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _pinsReady() {
    if (!RegExp(r'^\d{4}$').hasMatch(_pin.controller.text)) {
      _pin.fail('Enter 4 digits.');
      return false;
    }
    if (_again.controller.text != _pin.controller.text) {
      _again.fail('The PINs don’t match.');
      return false;
    }
    return true;
  }

  Future<void> _save(PinStep step) async {
    final pins = ref.read(pinServiceProvider);
    if (pins == null || _saving) return;
    if (step == PinStep.change &&
        !RegExp(r'^\d{4}$').hasMatch(_current.controller.text)) {
      _current.fail('Enter 4 digits.');
      return;
    }
    final code = _code.controller.text.replaceAll(' ', '');
    final byCode = step == PinStep.reset || !_usePassword;
    if (step != PinStep.change && byCode && code.length != 6) {
      _code.fail('Enter the 6-digit code.');
      return;
    }
    if (step == PinStep.create && !byCode && _password.text.isEmpty) {
      _password.nudge();
      return;
    }
    if (!_pinsReady()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _banner = null;
    });
    final pin = _pin.controller.text;
    try {
      await switch (step) {
        PinStep.create => pins.create(
          pin,
          code: byCode ? code : null,
          password: byCode ? null : _password.controller.text,
        ),
        PinStep.change => pins.change(_current.controller.text, pin),
        PinStep.reset => pins.reset(code, pin),
      };
    } on PinRefused catch (refused) {
      if (!mounted) return;
      setState(() => _saving = false);
      _refused(refused);
      return;
    }
    if (!mounted) return;
    ref.invalidate(pinStatusProvider);
    IqHaptics.success.play();
    goBack(context);
  }

  void _refused(PinRefused refused) {
    final now = ref.read(clockProvider)();
    switch (refused.problem) {
      case PinProblem.incorrect:
        _current.controller.clear();
        _current.fail(pinTriesLeft(refused.attemptsLeft));
      case PinProblem.codeInvalid:
        final left = refused.attemptsLeft;
        _code.fail(
          left == null
              ? 'That code isn’t right.'
              : 'That code isn’t right. $left '
                    '${left == 1 ? 'try' : 'tries'} left.',
        );
      case PinProblem.codeExpired:
        _code.fail('That code has expired. Send a new one.');
        _countDown(null);
      case PinProblem.passwordIncorrect:
        _password.fail('That password isn’t right.');
      case PinProblem.passwordNotSet:
        setState(() {
          _usePassword = false;
          _banner =
              'Your account signs in with Google or Apple. Use an emailed '
              'code.';
        });
      case PinProblem.locked:
        errorHaptic();
        setState(() {
          _banner =
              'Locked after 5 wrong PINs. '
              '${pinLockWait(refused.retryAfter, null, now)}, or reset it '
              'by email.';
          _bannerResets = true;
        });
      case PinProblem.resetRequired:
        errorHaptic();
        _go(
          PinStep.reset,
          banner: 'Your PIN is locked. Reset it by email to use it again.',
        );
      case PinProblem.alreadySet:
        ref.invalidate(pinStatusProvider);
        _go(PinStep.change, banner: 'You already have a PIN. Change it here.');
      case PinProblem.notSet:
        ref.invalidate(pinStatusProvider);
        _go(PinStep.create);
      case PinProblem.rateLimited:
        errorHaptic();
        setState(
          () => _banner =
              'Too many tries. '
              '${pinLockWait(refused.retryAfter, null, now)}.',
        );
      case PinProblem.offline:
        errorHaptic();
        setState(() => _banner = 'No connection. Nothing was saved.');
      case PinProblem.closing || PinProblem.required || PinProblem.unknown:
        errorHaptic();
        setState(() => _banner = 'Not saved. Try again.');
    }
  }

  Widget _pinField(EntryInput input, String label, {bool autofocus = false}) =>
      ListenableBuilder(
        listenable: input.changes,
        builder: (context, _) => Shake(
          trigger: input.fails,
          child: IqField(
            label: label,
            value: '• • • •',
            help: input.error ?? '',
            state: input.error != null ? IqFieldState.error : null,
            showNote: false,
            controller: input.controller,
            focusNode: input.focus,
            autofocus: autofocus,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
          ),
        ),
      );

  Widget _codeField() {
    final left = _left();
    final seconds = left.inSeconds;
    final wait =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    final sentTo = _sentTo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListenableBuilder(
          listenable: _code.changes,
          builder: (context, _) => Shake(
            trigger: _code.fails,
            child: IqField(
              label: '6-digit code',
              value: '',
              help: _code.error ?? '',
              state: _code.error != null ? IqFieldState.error : null,
              showNote: false,
              controller: _code.controller,
              focusNode: _code.focus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
            ),
          ),
        ),
        const SizedBox(height: IqSpace.s2),
        GestureDetector(
          onTap: left > Duration.zero ? null : _sendCode,
          child: Text(switch ((sentTo, left > Duration.zero)) {
            (_, true) =>
              'Sent${sentTo == null ? '' : ' to $sentTo'}. Resend in $wait.',
            (null, false) => 'Email me a code.',
            (_, false) => 'Sent to $sentTo. Didn’t get it? Resend the code.',
          }, style: IqText.small.copyWith(color: IqColors.fg2)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(pinStatusProvider);
    final loaded = status.value;
    final step = _stepFor(loaded);
    final failed = status.hasError && _step == null;
    final banner = failed ? 'Couldn’t load. Check your connection.' : _banner;
    return SubPage(
      title: 'iQLY PIN',
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
        children: [
          IqBanner(
            kind: IqBannerKind.error,
            title: banner ?? '',
            visible: banner != null,
            action: failed
                ? 'Try again'
                : _bannerResets
                ? 'Reset'
                : null,
            showAction: failed || _bannerResets,
            onAction: failed
                ? () => ref.invalidate(pinStatusProvider)
                : () => _go(PinStep.reset),
            margin: const EdgeInsets.only(bottom: IqSpace.s3),
          ),
          if (loaded != null || _step != null) ...[
            Text(switch (step) {
              PinStep.create =>
                'Your 4-digit iQLY PIN confirms every withdrawal.',
              PinStep.change => 'Enter your PIN, then the new one.',
              PinStep.reset =>
                'We email you a code. It sets a new PIN and unlocks it.',
            }, style: IqText.body.copyWith(color: IqColors.fg2)),
            const SizedBox(height: IqSpace.s3),
            if (step == PinStep.change) ...[
              _pinField(_current, 'Current PIN', autofocus: true),
              const SizedBox(height: IqSpace.s2),
            ],
            if (step == PinStep.reset ||
                (step == PinStep.create && !_usePassword)) ...[
              _codeField(),
              const SizedBox(height: IqSpace.s3),
            ],
            if (step == PinStep.create && _usePassword) ...[
              ListenableBuilder(
                listenable: _password.changes,
                builder: (context, _) => Shake(
                  trigger: _password.fails,
                  child: IqField(
                    label: 'Password',
                    value: '',
                    help: _password.error ?? '',
                    state: _password.error != null ? IqFieldState.error : null,
                    showNote: false,
                    controller: _password.controller,
                    focusNode: _password.focus,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                  ),
                ),
              ),
              const SizedBox(height: IqSpace.s3),
            ],
            _pinField(_pin, 'New PIN'),
            const SizedBox(height: IqSpace.s2),
            _pinField(_again, 'New PIN again'),
            const SizedBox(height: IqSpace.s3),
            if (step == PinStep.create)
              IqButton(
                label: _usePassword
                    ? 'Use an emailed code instead'
                    : 'Use your password instead',
                kind: IqButtonKind.ghost,
                width: double.infinity,
                onTap: () => setState(() {
                  _usePassword = !_usePassword;
                  _banner = null;
                }),
              ),
            if (step == PinStep.change)
              IqButton(
                label: 'Forgot it? Reset it by email',
                kind: IqButtonKind.ghost,
                width: double.infinity,
                onTap: () => _go(PinStep.reset),
              ),
          ],
        ],
      ),
      actions: [
        IqButton(
          label: 'Save PIN',
          showIcon: false,
          width: double.infinity,
          loading: _saving,
          disabled: loaded == null && _step == null,
          onTap: () => _save(step),
        ),
      ],
    );
  }
}
