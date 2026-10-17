import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/backend.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/session.dart';
import '../../data/api_client.dart';
import '../../data/live/live_repository.dart';
import '../../data/models.dart';
import '../../data/wallet_service.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/option_row.dart';
import '../../ui/toast.dart';
import '../../ui/top_bar.dart';
import '../entry/entry_copy.dart';
import 'pin_sheet.dart';
import 'wallet_sheet.dart';
import 'wallet_state.dart';

/// B5 · Bank account sheet (332:15657): the saved accounts, default first.
/// From the Wallet it manages them: pick one that is not the default and
/// Set as default asks for the PIN, then switches (designer answer 14). From the Withdraw "To"
/// picker ([picking]) a row picks the destination and closes (designer
/// answer 5). Add a bank account goes to Select bank. A live sheet asks for
/// no PIN, and a withdrawal keeps the account it was sent to, so it names
/// that account. While the API keeps several accounts (contract 10.2) the
/// selected one can also be removed, after a confirm.
class BankAccountSheet extends ConsumerStatefulWidget {
  const BankAccountSheet({super.key, this.picking});

  /// The destination the Withdraw sheet holds now; set when picking.
  final SavedBank? picking;

  static const inUse =
      'A withdrawal to this account is still on its way. You can remove it '
      'once it arrives.';
  static const notRemoved = 'Couldn’t remove the account. Try again.';
  static const notSwitched = 'Couldn’t switch the default. Try again.';
  static const gone =
      'That account is no longer saved. Here are the accounts you have now.';

  @override
  ConsumerState<BankAccountSheet> createState() => _BankAccountSheetState();
}

class _BankAccountSheetState extends ConsumerState<BankAccountSheet> {
  String? _picked;
  bool _covered = false;
  bool _saving = false;
  bool _removing = false;
  String? _error;

  bool get _picking => widget.picking != null;

  void _cover(bool covered) {
    setState(() => _covered = covered);
  }

  Future<void> _addAccount() async {
    await context.push<bool>(Routes.selectBank);
  }

  Future<void> _setDefault(WalletData data, {required bool live}) async {
    final picked = data.accounts.where((a) => a.key == _picked).firstOrNull;
    if (picked == null || picked.key == data.savedBank?.key) {
      Navigator.of(context).pop();
      return;
    }
    if (!live) {
      final ok = await showOverSheet<bool>(
        context,
        (context) => PinSheet(
          body:
              'Make ${picked.label} your default. Your 4-digit iQLY PIN confirms the switch.',
          action: 'Set as default',
        ),
        cover: _cover,
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final scope = ref.read(accountScopeProvider);
    try {
      await ref.read(walletServiceProvider).setDefault(picked);
    } on Exception catch (error) {
      if (!mounted) return;
      final gone = _gone(error);
      setState(() {
        _saving = false;
        if (gone) _picked = null;
        _error = gone
            ? BankAccountSheet.gone
            : error is ApiUnreachable
            ? EntryCopy.offline
            : BankAccountSheet.notSwitched;
      });
      return;
    }
    if (!mounted || !scope.open) return;
    ref.read(walletProvider.notifier).setDefault(picked);
    Navigator.of(context).pop();
  }

  /// Asks first. A withdrawal on its way to the account keeps it
  /// (BANK_ACCOUNT_IN_USE).
  Future<void> _remove(SavedBank account) async {
    final remove = await showIqConfirmSheet(
      context,
      title: 'Remove this account?',
      body:
          '${account.label} will no longer get payouts. You can add it again '
          'later.',
      confirmLabel: 'Remove account',
      cancelLabel: 'Keep it',
    );
    if (!remove || !mounted) return;
    setState(() {
      _removing = true;
      _error = null;
    });
    final scope = ref.read(accountScopeProvider);
    final List<SavedBank> left;
    try {
      left = await ref.read(walletServiceProvider).removeAccount(account);
    } on Exception catch (error) {
      if (!mounted) return;
      final gone = _gone(error);
      setState(() {
        _removing = false;
        if (gone) _picked = null;
        _error = switch (error) {
          _ when gone => BankAccountSheet.gone,
          ApiRefused(code: 'BANK_ACCOUNT_IN_USE') => BankAccountSheet.inUse,
          ApiUnreachable() => EntryCopy.offline,
          _ => BankAccountSheet.notRemoved,
        };
      });
      errorHaptic();
      return;
    }
    if (!mounted || !scope.open) return;
    ref.read(walletProvider.notifier).setAccounts(left);
    setState(() {
      _removing = false;
      _picked = null;
    });
    IqToast.show(context, 'Account removed');
  }

  /// An account another phone removed: the list reloads, so no stale id
  /// is ever sent again.
  bool _gone(Exception error) {
    if (error is! ApiRefused || error.code != 'BANK_ACCOUNT_NOT_FOUND') {
      return false;
    }
    unawaited(ref.read(walletProvider.notifier).refreshQuietly());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(walletProvider).value;
    final accounts = data?.accounts ?? const <SavedBank>[];
    final current = _picking
        ? widget.picking!.key
        : _picked ?? data?.savedBank?.key;
    final pending = data?.totals.pendingWithdrawalsKobo ?? 0;
    final mode = ref.watch(liveModeProvider);
    final live = !mode.isPreview;
    final several = mode.isLive(LiveFeature.bankAccounts);
    final pendingTo = live
        ? data?.withdrawals.where((w) => w.onHold).firstOrNull?.destination
        : data?.savedBank?.label;
    final note = [
      if (pending > 0 && pendingTo != null)
        'Your pending ${naira(pending)} still goes to $pendingTo.',
      if (!live) 'We ask for your PIN before switching.',
    ].join(' ');
    final selected = accounts.where((a) => a.key == current).firstOrNull;
    final error = _error;

    return SheetCover(
      covered: _covered,
      child: WalletSheet(
        children: [
          IqTopBar(
            variant: IqTopBarVariant.sheet,
            title: 'Bank account',
            onClose: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s4,
              IqSpace.s2,
              IqSpace.s4,
              IqSpace.s4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, account) in accounts.indexed) ...[
                  IqOptionRow(
                    label: account.label,
                    note: [account.holder, if (i == 0) 'Default'].join(' · '),
                    state: account.key == current
                        ? IqOptionRowState.selected
                        : IqOptionRowState.standard,
                    onTap: () {
                      if (_picking) {
                        Navigator.of(context).pop(account);
                      } else {
                        setState(() {
                          _picked = account.key;
                          _error = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: IqSpace.s3),
                ],
                IqButton(
                  label: several && accounts.isNotEmpty
                      ? 'Add another'
                      : 'Add a bank account',
                  kind: IqButtonKind.ghost,
                  showIcon: false,
                  width: double.infinity,
                  onTap: _addAccount,
                ),
                if (error != null) ...[
                  const SizedBox(height: IqSpace.s3),
                  Text(
                    error,
                    style: IqText.small.copyWith(color: IqColors.err),
                  ),
                ],
                if (!_picking &&
                    data != null &&
                    current != data.savedBank?.key) ...[
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: IqSpace.s3),
                    Text(
                      note,
                      style: IqText.small.copyWith(color: IqColors.fg2),
                    ),
                  ],
                  const SizedBox(height: IqSpace.s3),
                  IqButton(
                    label: 'Set as default',
                    width: double.infinity,
                    loading: _saving,
                    onTap: () => _setDefault(data, live: live),
                  ),
                ],
                if (!_picking && several && selected != null) ...[
                  const SizedBox(height: IqSpace.s3),
                  IqButton(
                    label: 'Remove',
                    kind: IqButtonKind.secondary,
                    showIcon: false,
                    width: double.infinity,
                    loading: _removing,
                    onTap: () => _remove(selected),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
