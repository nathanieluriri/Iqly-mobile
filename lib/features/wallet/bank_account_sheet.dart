import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/wallet_service.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/option_row.dart';
import '../../ui/top_bar.dart';
import 'pin_sheet.dart';
import 'wallet_sheet.dart';
import 'wallet_state.dart';

/// B5 · Bank account sheet (332:15657): the saved accounts, default first.
/// From the Wallet it manages them: pick one and Set as default asks for
/// the PIN, then switches (designer answer 14). From the Withdraw "To"
/// picker ([picking]) a row picks the destination and closes (designer
/// answer 5). Add a bank account goes to Select bank.
class BankAccountSheet extends ConsumerStatefulWidget {
  const BankAccountSheet({super.key, this.picking});

  /// The destination the Withdraw sheet holds now; set when picking.
  final SavedBank? picking;

  @override
  ConsumerState<BankAccountSheet> createState() => _BankAccountSheetState();
}

class _BankAccountSheetState extends ConsumerState<BankAccountSheet> {
  String? _picked;
  bool _covered = false;
  bool _saving = false;

  bool get _picking => widget.picking != null;

  void _cover(bool covered) {
    setState(() => _covered = covered);
  }

  Future<void> _addAccount() async {
    await context.push<bool>(Routes.selectBank);
  }

  Future<void> _setDefault(WalletData data) async {
    final picked = data.accounts
        .where((a) => a.accountNumber == _picked)
        .firstOrNull;
    if (picked == null ||
        picked.accountNumber == data.savedBank?.accountNumber) {
      Navigator.of(context).pop();
      return;
    }
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
    setState(() => _saving = true);
    await ref.read(walletServiceProvider).setDefault(picked);
    if (!mounted) return;
    ref.read(walletProvider.notifier).setDefault(picked);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(walletProvider).value;
    final accounts = data?.accounts ?? const <SavedBank>[];
    final current = _picking
        ? widget.picking!.accountNumber
        : _picked ?? data?.savedBank?.accountNumber;
    final pending = data?.totals.pendingWithdrawalsKobo ?? 0;
    final defaultBank = data?.savedBank;

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
                    note: [
                      account.holder,
                      'Name verified',
                      if (i == 0) 'Default',
                    ].join(' · '),
                    state: account.accountNumber == current
                        ? IqOptionRowState.selected
                        : IqOptionRowState.standard,
                    onTap: () {
                      if (_picking) {
                        Navigator.of(context).pop(account);
                      } else {
                        setState(() => _picked = account.accountNumber);
                      }
                    },
                  ),
                  const SizedBox(height: IqSpace.s3),
                ],
                IqButton(
                  label: 'Add a bank account',
                  kind: IqButtonKind.ghost,
                  showIcon: false,
                  width: double.infinity,
                  onTap: _addAccount,
                ),
                if (!_picking) ...[
                  const SizedBox(height: IqSpace.s3),
                  Text(
                    [
                      if (pending > 0 && defaultBank != null)
                        'Your pending ${naira(pending)} still goes to ${defaultBank.label}.',
                      'We ask for your PIN before switching.',
                    ].join(' '),
                    style: IqText.small.copyWith(color: IqColors.fg2),
                  ),
                  const SizedBox(height: IqSpace.s3),
                  IqButton(
                    label: 'Set as default',
                    width: double.infinity,
                    loading: _saving,
                    onTap: data == null ? null : () => _setDefault(data),
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
