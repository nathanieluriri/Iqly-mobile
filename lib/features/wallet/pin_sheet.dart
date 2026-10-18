import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/transitions.dart';
import '../../data/biometric_service.dart';
import '../../data/pin_service.dart';
import '../../data/wallet_service.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../entry/entry_widgets.dart' show EntryInput;
import 'biometric_withdraw.dart';
import 'wallet_sheet.dart';
import 'withdrawal_pin_screen.dart'
    show openPinReset, pinLockWait, pinTriesLeft;

/// B5 · Withdraw · confirm with PIN (483:22222): the 4-digit iQLY PIN
/// confirms a withdrawal or a switch of the default account (designer
/// answers 4 and 14). The ghost offers the phone's own check when it has
/// one. Pops the PIN once confirmed ('' for the phone's own check).
///
/// While the API runs the PIN (contract 13.1) the API checks it: a wrong
/// one says the tries left, a lock how long it holds, and a lock only a
/// reset opens hands over to the reset from More. The phone's own check
/// then unlocks the PIN kept on the phone, once turned on from More.
///
/// There is no PIN kit component: Exp/Field and the buttons, as the frame
/// builds it. The Field help "Forgot it? Reset it by email from More." shows
/// when the PIN is refused (the frame hides it while Active).
class PinSheet extends ConsumerStatefulWidget {
  const PinSheet({
    super.key,
    required this.body,
    this.action = 'Confirm withdrawal',
    this.offerBiometric = true,
  });

  final String body;
  final String action;

  /// Offers the phone's check: while the API runs the PIN, only once it is
  /// turned on for withdrawals, since it then unlocks the kept PIN.
  final bool offerBiometric;

  static const lockedForReset =
      'Your PIN is locked. Reset it by email to use it again.';

  @override
  ConsumerState<PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends ConsumerState<PinSheet> {
  final _pin = EntryInput();
  BiometricKind? _biometric;
  bool _checking = false;
  bool _resetRequired = false;

  @override
  void initState() {
    super.initState();
    if (!widget.offerBiometric) return;
    if (ref.read(pinServiceProvider) != null) {
      ref.read(biometricWithdrawProvider.future).then((check) {
        if (mounted && check.on) setState(() => _biometric = check.kind);
      });
      return;
    }
    ref.read(biometricServiceProvider).available().then((kind) {
      if (mounted) setState(() => _biometric = kind);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    whenArrived(context, () {
      if (mounted) _pin.focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final pin = _pin.controller.text;
    if (pin.length != 4) {
      _pin.fail(_forgot);
      return;
    }
    setState(() => _checking = true);
    final pins = ref.read(pinServiceProvider);
    if (pins != null) return _verify(pins, pin);
    final ok = await ref.read(walletServiceProvider).confirmPin(pin);
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      Navigator.of(context).pop(pin);
      return;
    }
    _pin.controller.clear();
    _pin.fail(_forgot);
  }

  Future<void> _verify(PinService pins, String pin) async {
    try {
      await pins.verify(pin);
    } on PinRefused catch (refused) {
      if (!mounted) return;
      setState(() => _checking = false);
      _pin.controller.clear();
      final now = ref.read(clockProvider)();
      switch (refused.problem) {
        case PinProblem.notSet:
          Navigator.of(context).pop('');
        case PinProblem.resetRequired:
          setState(() => _resetRequired = true);
          _pin.fail(PinSheet.lockedForReset);
        case PinProblem.incorrect:
          _pin.fail('${pinTriesLeft(refused.attemptsLeft)} $_forgot');
        case PinProblem.locked:
          _pin.fail(
            'Locked after 5 wrong PINs. '
            '${pinLockWait(refused.retryAfter, null, now)}, or reset it by '
            'email from More.',
          );
        case PinProblem.offline:
          _pin.fail('No connection. Try again.');
        case _:
          _pin.fail('Couldn’t check your PIN. Try again.');
      }
      return;
    }
    if (mounted) Navigator.of(context).pop(pin);
  }

  /// Closes the sheets and opens the reset from More, where the help line
  /// points; Back from it lands on More.
  void _reset() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    openPinReset(router);
  }

  Future<void> _useBiometric() async {
    if (ref.read(pinServiceProvider) != null) {
      final pin = await pinFromBiometrics(ref, widget.action);
      if (pin != null && mounted) Navigator.of(context).pop(pin);
      return;
    }
    final ok = await ref.read(biometricServiceProvider).confirm(widget.action);
    if (ok && mounted) Navigator.of(context).pop('');
  }

  static const _forgot = 'Forgot it? Reset it by email from More.';

  @override
  Widget build(BuildContext context) {
    final biometric = _biometric;
    return WalletSheet(
      clearIndicator: false,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, IqSpace.s3, 20, 28),
          child: ListenableBuilder(
            listenable: _pin.changes,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: IqColors.line2,
                      borderRadius: BorderRadius.circular(IqRadius.full),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Confirm with your PIN',
                  style: IqText.headline.copyWith(color: IqColors.fg),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.body,
                  style: IqText.body.copyWith(color: IqColors.fg2),
                ),
                const SizedBox(height: 14),
                Shake(
                  trigger: _pin.fails,
                  child: IqField(
                    label: 'iQLY PIN',
                    value: '• • • •',
                    help: _pin.error ?? _forgot,
                    state: _pin.error != null ? IqFieldState.error : null,
                    showNote: false,
                    controller: _pin.controller,
                    focusNode: _pin.focus,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _confirm(),
                  ),
                ),
                const SizedBox(height: 14),
                IqButton(
                  label: _resetRequired ? 'Reset it by email' : widget.action,
                  width: double.infinity,
                  loading: _checking,
                  onTap: _resetRequired ? _reset : _confirm,
                ),
                if (biometric != null) ...[
                  const SizedBox(height: 14),
                  IqButton(
                    label: 'Use ${biometric.label} instead',
                    kind: IqButtonKind.ghost,
                    width: double.infinity,
                    onTap: _useBiometric,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
