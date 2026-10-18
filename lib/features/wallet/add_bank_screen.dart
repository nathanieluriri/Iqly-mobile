import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/session.dart';
import '../../core/transitions.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/wallet_service.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/highlight.dart';
import '../../ui/top_bar.dart';
import '../entry/entry_copy.dart';
import '../entry/entry_widgets.dart' show EntryInput;
import 'wallet_routes.dart';
import 'wallet_state.dart';

/// Exp/Field help for an account the bank could not match.
const verifyHelp = 'Could not verify account. Check the number and bank.';

/// A sixth saved account (409 BANK_ACCOUNT_LIMIT).
const accountLimitHelp =
    'You can keep up to 5 bank accounts. Remove one to add another.';

/// B5 · Add bank · account number (483:22323) and name verified
/// (483:22389). Check the name asks the bank for the name on the ten
/// digits; once verified, Save account saves it and pops true. A save the
/// API refuses stays on the page with the field's own error.
class AddBankScreen extends ConsumerStatefulWidget {
  const AddBankScreen({super.key, required this.bankCode});

  final String bankCode;

  @override
  ConsumerState<AddBankScreen> createState() => _AddBankScreenState();
}

class _AddBankScreenState extends ConsumerState<AddBankScreen> {
  final _number = EntryInput();
  String? _verifiedName;
  String _verifiedNumber = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _number.controller.addListener(() {
      if (_verifiedName != null && _number.controller.text != _verifiedNumber) {
        setState(() => _verifiedName = null);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    whenArrived(context, () {
      if (mounted && _verifiedName == null) _number.focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  String _bankName(WalletData? data) =>
      data?.banks.where((b) => b.code == widget.bankCode).firstOrNull?.name ??
      '';

  Future<void> _check() async {
    final number = _number.controller.text;
    if (number.length != 10) {
      _number.fail(verifyHelp);
      return;
    }
    setState(() => _busy = true);
    final result = await ref
        .read(walletServiceProvider)
        .verifyAccount(bankCode: widget.bankCode, accountNumber: number);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      _number.fail(
        result.failure == WalletFailure.offline
            ? EntryCopy.offline
            : verifyHelp,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    IqHaptics.success.play();
    setState(() {
      _verifiedName = result.accountName;
      _verifiedNumber = number;
    });
  }

  Future<void> _save(WalletData? data) async {
    final name = _verifiedName;
    if (name == null) return;
    setState(() => _busy = true);
    final scope = ref.read(accountScopeProvider);
    final SavedBank account;
    try {
      account = await ref
          .read(walletServiceProvider)
          .addAccount(
            SavedBank(
              bankCode: widget.bankCode,
              bankName: _bankName(data),
              accountName: name,
              accountNumber: _verifiedNumber,
            ),
          );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _number.fail(switch (error) {
        ApiUnreachable() => EntryCopy.offline,
        ApiRefused(code: 'BANK_ACCOUNT_LIMIT') => accountLimitHelp,
        _ => verifyHelp,
      });
      return;
    }
    if (!mounted || !scope.open) return;
    ref.read(walletProvider.notifier).addAccount(account);
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(walletProvider).value;
    final bank = _bankName(data);
    final verified = _verifiedName;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Add a bank account',
                  onBack: () => leaveWallet(context),
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: _number.changes,
                    builder: (context, _) => ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: IqSpace.s4,
                      ),
                      children: [
                        Shake(
                          trigger: _number.fails,
                          child: IqField(
                            label: 'Account number',
                            value: '0123456789',
                            state: _number.error != null
                                ? IqFieldState.error
                                : verified != null
                                ? IqFieldState.valid
                                : null,
                            help: _number.error ?? verifyHelp,
                            note: '$bank · 10 digits',
                            showNote: verified != null,
                            controller: _number.controller,
                            focusNode: _number.focus,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _check(),
                          ),
                        ),
                        if (verified != null) ...[
                          const SizedBox(height: IqSpace.s2),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IqHighlight(
                              text: verified
                                  .trim()
                                  .split(RegExp(r'\s+'))
                                  .join(' '),
                              tone: IqHighlightTone.green,
                            ),
                          ),
                        ],
                        const SizedBox(height: IqSpace.s2),
                        Text(
                          'We check the name with $bank before saving. '
                          'Payouts only go to an account in your own name.',
                          style: IqText.small.copyWith(color: IqColors.fg2),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    IqSpace.s3,
                    IqSpace.s4,
                    IqSpace.s3,
                  ),
                  child: ListenableBuilder(
                    listenable: _number.changes,
                    builder: (context, _) => IqButton(
                      label: verified == null
                          ? 'Check the name'
                          : 'Save account',
                      showIcon: false,
                      width: double.infinity,
                      loading: _busy,
                      disabled:
                          verified == null &&
                          _number.controller.text.length != 10,
                      onTap: verified == null ? _check : () => _save(data),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
