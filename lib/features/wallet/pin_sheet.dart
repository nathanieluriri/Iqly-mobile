import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/transitions.dart';
import '../../data/biometric_service.dart';
import '../../data/wallet_service.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../entry/entry_widgets.dart' show EntryInput;
import 'wallet_sheet.dart';

/// B5 · Withdraw · confirm with PIN (483:22222): the 4-digit iQLY PIN
/// confirms a withdrawal or a switch of the default account (designer
/// answers 4 and 14). The ghost offers the phone's own check when it has
/// one. Pops true once confirmed.
///
/// There is no PIN kit component: Exp/Field and the buttons, as the frame
/// builds it. The Field help "Forgot it? Reset it by email from More." shows
/// when the PIN is refused (the frame hides it while Active).
class PinSheet extends ConsumerStatefulWidget {
  const PinSheet({
    super.key,
    required this.body,
    this.action = 'Confirm withdrawal',
  });

  final String body;
  final String action;

  @override
  ConsumerState<PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends ConsumerState<PinSheet> {
  final _pin = EntryInput();
  BiometricKind? _biometric;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
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
    final ok = await ref.read(walletServiceProvider).confirmPin(pin);
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    _pin.controller.clear();
    _pin.fail(_forgot);
  }

  Future<void> _useBiometric() async {
    final ok = await ref.read(biometricServiceProvider).confirm(widget.action);
    if (ok && mounted) Navigator.of(context).pop(true);
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
                  label: widget.action,
                  width: double.infinity,
                  loading: _checking,
                  onTap: _confirm,
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
