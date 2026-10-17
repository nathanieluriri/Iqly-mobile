import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/transitions.dart';
import '../../data/biometric_service.dart';
import '../../data/live/live_repository.dart';
import '../../data/models.dart';
import '../../data/wallet_service.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/highlight.dart';
import '../../ui/top_bar.dart';
import '../entry/entry_widgets.dart' show EntryInput;
import '../profile/profile_routes.dart';
import '../profile/your_details_screen.dart';
import '../settings/restore_account_screen.dart';
import 'bank_account_sheet.dart';
import 'pin_sheet.dart';
import 'wallet_format.dart';
import 'wallet_routes.dart';
import 'wallet_sheet.dart';
import 'wallet_state.dart';

/// B5 · Withdraw sheet (40:9785) and its states: above available
/// (483:21751), below minimum (483:21872), sending (483:21992) and no
/// connection (483:22107). The whole withdrawable balance is never below the
/// minimum (contract 6), so a remainder under ₦1,000 can leave; any other
/// amount under ₦1,000 is. "You can withdraw up to" sits over the Amount
/// (designer doc rev 55). To opens the Bank account sheet to pick the
/// destination (answer 5). Withdraw confirms with the phone's own check
/// when it has one, otherwise the iQLY PIN (answer 4, 483:22222); then the
/// button sends, the sheet drops and Withdrawal pending pushes. The live API
/// has no PIN yet (nor does the web), so a live launch goes straight to the
/// request, which a paused feature refuses.
///
/// A request whose answer was lost may have reached the API, so its banner
/// keeps only the first sentence ("No connection.", "Couldn't send.": the
/// frames have no state for it), the wallet reloads behind it, and the next
/// Withdraw sends that request again first; a withdrawal it made opens its
/// tracker. Asked without a date of birth, or with one under 18, the API
/// refuses until the profile has an adult date, so Date of birth opens; a
/// closing account goes to Restore.
class WithdrawSheet extends ConsumerStatefulWidget {
  const WithdrawSheet({super.key, this.amountKobo, this.account});

  final int? amountKobo;

  /// The saved account to send to, by its id (or key in the demo).
  final String? account;

  @override
  ConsumerState<WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<WithdrawSheet> {
  late final _amount = EntryInput(
    widget.amountKobo == null ? '' : naira(widget.amountKobo!),
  );
  SavedBank? _to;
  bool _belowShown = false;
  bool _sending = false;
  bool _covered = false;
  WalletFailure? _failure;
  bool _unsettled = false;

  /// What the amount reads as. Tidying it as the field lets go, or moving
  /// the caret, is not an edit, so a refusal that lands first stays shown.
  int? _kobo;

  @override
  void initState() {
    super.initState();
    _kobo = parseNaira(_amount.controller.text);
    _amount.focus.addListener(_onAmountFocus);
    _amount.controller.addListener(_onAmountEdit);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    whenArrived(context, () {
      if (mounted) _amount.focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _onAmountEdit() {
    final kobo = parseNaira(_amount.controller.text);
    if (kobo == _kobo) return;
    _kobo = kobo;
    if (_belowShown || _failure != null) {
      setState(() {
        _belowShown = false;
        _failure = null;
        _unsettled = false;
      });
    }
  }

  void _onAmountFocus() {
    if (_amount.focus.hasFocus) return;
    final kobo = parseNaira(_amount.controller.text);
    if (kobo == null) return;
    final shown = naira(kobo);
    if (shown != _amount.controller.text) _amount.controller.text = shown;
    if (belowMinimum(kobo, _available(ref.read(walletProvider).value))) {
      setState(() => _belowShown = true);
    }
  }

  static int _available(WalletData? data) => data?.totals.withdrawableKobo ?? 0;

  SavedBank? _destination(WalletData? data) {
    final picked = _to;
    if (picked != null) return picked;
    final wanted = widget.account;
    final accounts = data?.accounts ?? const <SavedBank>[];
    if (wanted != null) {
      final match = accounts
          .where((a) => a.id == wanted || a.key == wanted)
          .firstOrNull;
      if (match != null) return match;
    }
    return data?.savedBank;
  }

  void _cover(bool covered) => setState(() => _covered = covered);

  Future<void> _pickAccount(WalletData? data) async {
    FocusScope.of(context).unfocus();
    final account = await showOverSheet<SavedBank>(
      context,
      (context) => BankAccountSheet(picking: _destination(data)),
      cover: _cover,
    );
    if (account != null && mounted) setState(() => _to = account);
  }

  Future<void> _withdraw() async {
    if (_sending) return;
    final data = ref.read(walletProvider).value;
    final to = _destination(data);
    final kobo = parseNaira(_amount.controller.text);
    final available = _available(data);
    if (to == null) {
      await _pickAccount(data);
      return;
    }
    if (kobo == null || belowMinimum(kobo, available)) {
      setState(() => _belowShown = true);
      errorHaptic();
      return;
    }
    if (kobo > available) return;
    FocusScope.of(context).unfocus();
    if (!ref.read(liveModeProvider).isPreview) {
      await _send(kobo, to);
      return;
    }
    final biometrics = ref.read(biometricServiceProvider);
    var confirmed = false;
    final kind = await biometrics.available();
    if (!mounted) return;
    if (kind != null) {
      confirmed = await biometrics.confirm('Confirm withdrawal');
      if (!mounted) return;
    }
    if (!confirmed) {
      confirmed =
          await showOverSheet<bool>(
            context,
            (context) => PinSheet(
              body:
                  '${naira(kobo)} to ${to.label}. Your 4-digit iQLY PIN confirms every withdrawal.',
            ),
            cover: _cover,
          ) ??
          false;
    }
    if (!confirmed || !mounted) return;
    await _send(kobo, to);
  }

  Future<void> _send(int kobo, SavedBank to) async {
    setState(() {
      _sending = true;
      _failure = null;
      _unsettled = false;
    });
    final result = await ref
        .read(walletServiceProvider)
        .withdraw(amountKobo: kobo, account: to);
    if (!mounted) return;
    final withdrawal = result.withdrawal;
    if (withdrawal == null) {
      final failure = result.failure;
      final fix = switch (failure) {
        WalletFailure.profileIncomplete ||
        WalletFailure.underAge => _openDateOfBirth,
        WalletFailure.closing when Flags.deleteAccount => _openClosing,
        _ => null,
      };
      final gone = failure == WalletFailure.accountGone;
      setState(() {
        _sending = false;
        _failure = failure;
        _unsettled = result.unsettled;
        if (gone) _to = null;
      });
      if (result.unsettled || gone) {
        unawaited(ref.read(walletProvider.notifier).refreshQuietly());
      }
      errorHaptic();
      await fix?.call();
      return;
    }
    ref.read(walletProvider.notifier).add(withdrawal);
    final router = GoRouter.of(context);
    final sheet = ModalRoute.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    router.pop();
    final under = router.state.uri;
    if (!reduced && sheet != null) await sheet.completed;
    IqHaptics.success.play();
    if (router.state.uri == under) {
      router.open(
        result.earlier
            ? withdrawalPath(withdrawal.id)
            : withdrawalPendingPath(withdrawal.id),
      );
    }
  }

  Future<void> _openDateOfBirth() async {
    await context.open<void>(editDetailPath(DetailField.dateOfBirth));
  }

  Future<void> _openClosing() => showClosingAccount(context, ref);

  void _retry() {
    final data = ref.read(walletProvider).value;
    final kobo = parseNaira(_amount.controller.text);
    final to = _destination(data);
    if (kobo == null || to == null) return;
    _send(kobo, to);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(walletProvider).value;
    final available = _available(data);
    final to = _destination(data);

    return SheetCover(
      covered: _covered,
      child: ListenableBuilder(
        listenable: _amount.changes,
        builder: (context, _) {
          final kobo = parseNaira(_amount.controller.text);
          final over = kobo != null && kobo > available;
          final below =
              _belowShown && kobo != null && belowMinimum(kobo, available);
          final error = over
              ? 'You have ${naira(available)} available.'
              : below
              ? 'Minimum withdrawal is ${naira(minimumWithdrawalKobo)}.'
              : null;
          final failure = _failure;
          return WalletSheet(
            children: [
              IqTopBar(
                variant: IqTopBarVariant.sheet,
                title: 'Withdraw',
                onClose: () => context.pop(),
              ),
              if (failure != null)
                IqBanner(
                  kind: IqBannerKind.error,
                  title: switch ((failure, _unsettled)) {
                    (WalletFailure.offline, false) =>
                      'No connection. Nothing was sent.',
                    (WalletFailure.offline, true) => 'No connection.',
                    (WalletFailure.accountGone, _) =>
                      'That account is no longer saved. Nothing was sent.',
                    (_, false) => 'Couldn’t send. Nothing was sent.',
                    (_, true) => 'Couldn’t send.',
                  },
                  action: 'Try again',
                  onAction: _retry,
                ),
              const SizedBox(height: 32),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: IqSpace.s4,
                    vertical: IqSpace.s3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IqHighlight(
                          text:
                              'You can withdraw up to ${naira(available)} right now',
                          tone: IqHighlightTone.lilac,
                        ),
                      ),
                      const SizedBox(height: IqSpace.s2),
                      Shake(
                        trigger: _amount.fails,
                        child: IqField(
                          label: 'Amount',
                          value: '₦0.00',
                          state: error != null ? IqFieldState.error : null,
                          help: error ?? '',
                          showNote: false,
                          controller: _amount.controller,
                          focusNode: _amount.focus,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: const [NairaInputFormatter()],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _withdraw(),
                        ),
                      ),
                      const SizedBox(height: IqSpace.s2),
                      IqField(
                        kind: IqFieldKind.picker,
                        pickerLabel: 'To',
                        pickerValue: to == null
                            ? ''
                            : '${to.label} · ${to.accountName}',
                        pickerPlaceholder: 'Select bank',
                        state: to == null
                            ? IqFieldState.empty
                            : IqFieldState.valid,
                        showStatus: false,
                        onTap: () => _pickAccount(data),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: IqSpace.s4,
                  vertical: IqSpace.s3,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IqButton(
                      label: 'Withdraw',
                      showIcon: false,
                      width: double.infinity,
                      loading: _sending,
                      disabled: error != null || kobo == null,
                      onTap: _withdraw,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Usually arrives in minutes. Can take up to 24 hours.',
                      textAlign: TextAlign.center,
                      style: IqText.small.copyWith(color: IqColors.fg3),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
