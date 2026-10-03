import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/models.dart';
import '../../data/wallet_service.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/progress_thread.dart';
import '../../ui/top_bar.dart';
import '../entry/entry_copy.dart';
import '../entry/entry_widgets.dart' show EntryInput;
import 'wallet_format.dart';
import 'wallet_routes.dart';
import 'wallet_state.dart';

/// Exp/Field help for an account the bank could not match.
const verifyHelp = 'Could not verify account. Check the number and bank.';

/// B5 · Withdraw sheet (40:9785), over the Wallet. AMOUNT follows the web
/// form (at least ₦1,000, no more than is available); TO is the saved bank,
/// or another bank from Select bank, which then needs its account number
/// verified. The ProgressThread tracks the two steps: the bank, then the
/// amount.
///
/// It rises on the .5 scrim (spec 3.3) and the field that owns the keyboard
/// takes focus once it has risen. The thread moves on its own (spec 5.26):
/// Ready on open draws its line, each step grows or shortens it.
///
/// Figma over the brief: the saved bank is a Picker labelled "To" with no
/// Verified line; another bank adds the ACCOUNT NUMBER field with the Valid
/// note and Error help of Exp/Field. The thread's hidden Progress text
/// ("Amount next · bank saved", 2 OF 2) comes from the frame's instance.
class WithdrawSheet extends ConsumerStatefulWidget {
  const WithdrawSheet({super.key, this.amountKobo, this.bankCode});

  final int? amountKobo;

  /// A bank picked in Select bank before the sheet opened.
  final String? bankCode;

  @override
  ConsumerState<WithdrawSheet> createState() => _WithdrawSheetState();
}

enum _Check { none, checking, verified, failed }

class _WithdrawSheetState extends ConsumerState<WithdrawSheet> {
  late final _amount = EntryInput(
    widget.amountKobo == null ? '' : naira(widget.amountKobo!),
  );
  final _account = EntryInput();
  late String? _bankCode = widget.bankCode;
  _Check _check = _Check.none;
  String? _accountName;
  String _checked = '';
  int _run = 0;
  bool _sending = false;
  WalletFailure? _sendFailure;
  bool _focusAsked = false;
  bool _arrived = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _amount.focus.addListener(_onAmountFocus);
    _amount.controller.addListener(_clearSendFailure);
    _account.controller.addListener(_onAccountEdit);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusAsked) return;
    _focusAsked = true;
    whenArrived(context, () {
      _arrived = true;
      _focusFirst();
    });
  }

  /// The field that owns the keyboard takes it once the sheet has risen and
  /// the wallet has loaded (a link can open the sheet before it has).
  void _focusFirst() {
    final data = ref.read(walletProvider).value;
    if (_focused || !_arrived || !mounted || data == null) return;
    _focused = true;
    (_usesSaved(data.savedBank) ? _amount : _account).focus.requestFocus();
  }

  @override
  void dispose() {
    _amount.dispose();
    _account.dispose();
    super.dispose();
  }

  bool _usesSaved(SavedBank? saved) =>
      saved != null && (_bankCode == null || _bankCode == saved.bankCode);

  void _clearSendFailure() {
    if (_sendFailure != null) setState(() => _sendFailure = null);
  }

  void _onAmountFocus() {
    if (_amount.focus.hasFocus || _amount.error != null) return;
    final kobo = parseNaira(_amount.controller.text);
    if (kobo == null) return;
    final shown = naira(kobo);
    if (shown != _amount.controller.text) _amount.controller.text = shown;
  }

  void _onAccountEdit() {
    final number = _account.controller.text;
    if (number == _checked) return;
    _checked = number;
    _run++;
    setState(() {
      _check = _Check.none;
      _accountName = null;
      _sendFailure = null;
    });
    if (number.length == 10) _verify(number);
  }

  Future<void> _verify(String number) async {
    final run = _run;
    setState(() => _check = _Check.checking);
    final result = await ref
        .read(walletServiceProvider)
        .verifyAccount(bankCode: _bankCode!, accountNumber: number);
    if (!mounted || run != _run) return;
    if (result.ok) {
      setState(() {
        _check = _Check.verified;
        _accountName = result.accountName;
      });
      IqHaptics.success.play();
      return;
    }
    setState(() => _check = _Check.failed);
    _account.fail(
      result.failure == WalletFailure.offline ? EntryCopy.offline : verifyHelp,
    );
  }

  Future<void> _pickBank() async {
    FocusScope.of(context).unfocus();
    final bank = await context.push<Bank>(Routes.selectBank);
    if (bank == null || !mounted) return;
    final saved = ref.read(walletProvider).value?.savedBank;
    setState(() {
      _bankCode = bank.code == saved?.bankCode ? null : bank.code;
      _sendFailure = null;
    });
    _account.controller.clear();
    if (!_usesSaved(saved)) _account.focus.requestFocus();
  }

  SavedBank? _destination(WalletData? data) {
    final saved = data?.savedBank;
    if (_usesSaved(saved)) return saved;
    final code = _bankCode;
    final name = _accountName;
    if (code == null || name == null || _check != _Check.verified) {
      return null;
    }
    return SavedBank(
      bankCode: code,
      bankName: _bankName(data, code),
      accountName: name,
      accountNumber: _account.controller.text,
    );
  }

  static String _bankName(WalletData? data, String code) =>
      data?.banks.where((b) => b.code == code).firstOrNull?.name ?? '';

  Future<void> _submit() async {
    if (_sending) return;
    final data = ref.read(walletProvider).value;
    final available = data?.totals.withdrawableKobo ?? 0;
    final kobo = parseNaira(_amount.controller.text);
    final destination = _destination(data);
    if (destination == null) {
      if (_bankCode == null) {
        await _pickBank();
      } else {
        _account.fail(verifyHelp);
      }
      return;
    }
    if (kobo == null || !validWithdrawal(kobo, available)) {
      _amount.fail(amountHelp(available));
      return;
    }
    setState(() {
      _sending = true;
      _sendFailure = null;
    });
    final result = await ref
        .read(walletServiceProvider)
        .withdraw(amountKobo: kobo, account: destination);
    if (!mounted) return;
    final withdrawal = result.withdrawal;
    if (withdrawal == null) {
      setState(() {
        _sending = false;
        _sendFailure = result.failure;
      });
      errorHaptic();
      return;
    }
    ref.read(walletProvider.notifier).add(withdrawal);
    IqHaptics.success.play();
    final router = GoRouter.of(context);
    router.pop();
    router.push(withdrawalPendingPath(withdrawal.id));
  }

  _ThreadLook _thread({required bool usesSaved, required bool amountValid}) {
    final failure = _sendFailure;
    if (failure != null) {
      return _ThreadLook.error(
        failure == WalletFailure.offline
            ? 'Couldn’t send. Check your connection.'
            : 'Couldn’t send. Try again.',
        '2 OF 2',
      );
    }
    if (usesSaved) {
      return amountValid
          ? const _ThreadLook.ready('Ready · bank saved')
          : const _ThreadLook.progress('Amount next · bank saved', '2 OF 2');
    }
    return switch (_check) {
      _Check.failed => const _ThreadLook.error(
        'Fix the account number',
        '1 OF 2',
      ),
      _Check.checking => const _ThreadLook.progress('Verifying…', '1 OF 2'),
      _Check.none => const _ThreadLook.progress(
        'Account number next',
        '1 OF 2',
      ),
      _Check.verified =>
        amountValid
            ? const _ThreadLook.ready('Ready · bank verified')
            : const _ThreadLook.progress(
                'Amount next · bank verified',
                '2 OF 2',
              ),
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(walletProvider, (previous, next) => _focusFirst());
    final data = ref.watch(walletProvider).value;
    final saved = data?.savedBank;
    final available = data?.totals.withdrawableKobo ?? 0;
    final usesSaved = _usesSaved(saved);
    final media = MediaQuery.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([_amount.changes, _account.changes]),
      builder: (context, _) {
        final kobo = parseNaira(_amount.controller.text);
        final over = kobo != null && kobo > available;
        final amountValid = validWithdrawal(kobo, available);
        final amountError = _amount.error != null || over;
        final IqFieldState? amountState = amountError
            ? IqFieldState.error
            : _amount.focus.hasFocus
            ? null
            : amountValid
            ? IqFieldState.valid
            : null;
        final IqFieldState? accountState = _account.error != null
            ? IqFieldState.error
            : _check == _Check.verified
            ? IqFieldState.valid
            : null;
        final code = _bankCode;
        final String? to = usesSaved
            ? '${saved!.bankName} ${saved.maskedNumber} · ${saved.accountName}'
            : code == null
            ? null
            : _bankName(data, code);

        return CenteredContent(
          child: Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    media.size.height -
                    media.viewInsets.bottom -
                    media.padding.top,
              ),
              child: Material(
                color: IqColors.bg,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IqTopBar(
                      variant: IqTopBarVariant.sheet,
                      title: 'Withdraw',
                      onClose: () => context.pop(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: IqSpace.s4,
                      ),
                      child: _thread(
                        usesSaved: usesSaved,
                        amountValid: amountValid,
                      ).build(),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(IqSpace.s3)
                            .copyWith(left: IqSpace.s4, right: IqSpace.s4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Shake(
                              trigger: _amount.fails,
                              child: IqField(
                                label: 'Amount',
                                value: '₦0.00',
                                state: amountState,
                                help: amountHelp(available),
                                showStatus: amountError,
                                showNote: false,
                                controller: _amount.controller,
                                focusNode: _amount.focus,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: const [NairaInputFormatter()],
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                              ),
                            ),
                            const SizedBox(height: IqSpace.s2),
                            IqField(
                              kind: IqFieldKind.picker,
                              pickerLabel: 'To',
                              pickerValue: to ?? '',
                              state: to == null
                                  ? IqFieldState.empty
                                  : IqFieldState.valid,
                              showStatus: false,
                              onTap: _pickBank,
                            ),
                            if (!usesSaved && code != null) ...[
                              const SizedBox(height: IqSpace.s2),
                              Shake(
                                trigger: _account.fails,
                                child: IqField(
                                  label: 'Account number',
                                  value: '0123456789',
                                  state: accountState,
                                  help: _account.error ?? verifyHelp,
                                  note: 'Verified: ${_accountName ?? ''}',
                                  controller: _account.controller,
                                  focusNode: _account.focus,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) =>
                                      _amount.focus.requestFocus(),
                                ),
                              ),
                            ],
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IqButton(
                            label: 'Withdraw',
                            width: double.infinity,
                            loading: _sending,
                            onTap: _submit,
                          ),
                          Text(
                            '1 to 2 business days',
                            textAlign: TextAlign.center,
                            style: IqText.small.copyWith(color: IqColors.fg3),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: media.padding.bottom),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThreadLook {
  const _ThreadLook.progress(this.text, this.count)
    : state = IqProgressThreadState.progress;
  const _ThreadLook.ready(this.text)
    : state = IqProgressThreadState.ready,
      count = '';
  const _ThreadLook.error(this.text, this.count)
    : state = IqProgressThreadState.error;

  final IqProgressThreadState state;
  final String text;
  final String count;

  IqProgressThread build() => IqProgressThread(
    state: state,
    status: text,
    count: count,
    readyText: text,
    errorText: text,
  );
}
