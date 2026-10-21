import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/biz_ledger_header.dart';
import '../../ui/biz_ledger_row.dart';
import '../../ui/button.dart';
import '../../ui/empty_state.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/meta.dart';
import '../../ui/pressable.dart';
import '../../ui/wallet_row.dart';
import '../shell/tablet_page.dart';
import '../shell/tablet_sheet.dart';
import 'wallet_routes.dart';
import 'wallet_rows.dart';
import 'wallet_state.dart';

/// T11 · Wallet (Mobile App · tablet, 1845:81025): Bank account and
/// Withdraw (the one primary) beside the hide-balance eye, the three
/// balances sharing the width, then the activity ledger. Portrait drops
/// the Type column, as each row's icon and detail already say it.
class TabletWallet extends ConsumerWidget {
  const TabletWallet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final data = wallet.value;
    final hidden = ref.watch(walletLensProvider).hidden;
    final briefs = ref.watch(rewardBriefsProvider).value ?? const {};
    final expanded = Layout.isExpanded(context);

    final actions = [
      _Eye(
        hidden: hidden,
        onTap: () => ref.read(walletLensProvider.notifier).toggleHidden(),
      ),
      IqButton(
        label: 'Bank account',
        kind: IqButtonKind.secondary,
        showIcon: false,
        width: 172,
        onTap: () => context.open(bankAccountPath),
      ),
      IqButton(
        label: 'Withdraw',
        showIcon: false,
        width: 148,
        disabled: data == null || data.totals.withdrawableKobo <= 0,
        onTap: () => context.open(Routes.withdraw),
      ),
    ];

    if (data == null) {
      return TabletPage(
        title: 'Wallet',
        actions: actions,
        children: [
          if (wallet.hasError)
            const IqEmptyState(
              figure: IqFigures.thinker,
              title: 'Couldn’t load your wallet',
              body: 'Check your data or Wi-Fi and try again.',
            )
          else
            const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: IqColors.primary),
              ),
            ),
        ],
      );
    }

    final totals = data.totals;
    final bank = data.savedBank;
    String shown(int kobo) => hidden ? hiddenAmount : naira(kobo);
    final balances = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (label, amount, caption)) in [
          (
            'Available to withdraw',
            totals.withdrawableKobo,
            data.activity.isEmpty || bank == null
                ? 'Win a brief to start earning'
                : 'Ready to withdraw to ${bank.label}',
          ),
          (
            'On its way to your bank',
            totals.pendingWithdrawalsKobo,
            'To ${bank?.label ?? ''} · usually arrives in minutes',
          ),
          (
            'Earned so far',
            totals.totalEarnedKobo,
            'From ${data.winningSubmissions} winning submissions',
          ),
        ].indexed) ...[
          if (i > 0) const SizedBox(width: IqSpace.s4),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(IqSpace.s5),
              decoration: BoxDecoration(
                color: IqColors.tint,
                borderRadius: BorderRadius.circular(IqRadius.xl2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: IqWebText.bodySmallStrong.copyWith(
                      color: IqColors.fg2,
                    ),
                  ),
                  const SizedBox(height: IqSpace.s1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      shown(amount),
                      style: IqText.figure.copyWith(color: IqColors.fg),
                    ),
                  ),
                  const SizedBox(height: IqSpace.s1),
                  Text(
                    caption,
                    style: IqWebText.bodySmall.copyWith(color: IqColors.fg2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );

    final columns = [
      const IqBizLedgerColumn('Date', width: 72, sorted: true),
      if (expanded) const IqBizLedgerColumn('Type', width: 104),
      const IqBizLedgerColumn('Description', flex: 3),
      const IqBizLedgerColumn('Status', flex: 2),
      const IqBizLedgerColumn('Amount', width: 120, end: true),
    ];
    final date = DateFormat('d MMM');
    final rows = [
      for (final item in data.activity)
        _row(context, item, columns, briefs, hidden, expanded, date),
    ];

    return TabletPage(
      title: 'Wallet',
      actions: actions,
      children: [
        balances,
        Text('Activity', style: IqText.title.copyWith(color: IqColors.fg)),
        if (rows.isEmpty)
          const IqEmptyState(
            figure: IqFigures.saver,
            title: 'No activity yet',
            body: 'Win a brief to start earning.',
          )
        else
          TabletCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqBizLedgerHeader(columns: columns),
                ...rows,
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    ActivityItem item,
    List<IqBizLedgerColumn> columns,
    Map<String, Brief> briefs,
    bool hidden,
    bool expanded,
    DateFormat date,
  ) {
    Widget text(String s, {Color color = IqColors.fg, bool strong = false}) =>
        Text(
          s,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (strong ? IqWebText.bodySmallStrong : IqWebText.bodySmall)
              .copyWith(color: color),
        );
    Widget describe(IqIcons icon, String title, String detail) => Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: IqColors.tint,
            borderRadius: BorderRadius.circular(IqRadius.lg),
          ),
          child: IqIcon(icon, size: 18, color: IqColors.brand),
        ),
        const SizedBox(width: IqSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text(title),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
              ),
            ],
          ),
        ),
      ],
    );
    final award = item.award;
    if (award != null) {
      final brief = briefs[award.submissionId];
      final (title, icon) = switch (award.source) {
        RewardSource.submission => (
          brief?.businessName ?? award.business ?? 'Private business',
          IqIcons.trophy,
        ),
        RewardSource.activation => (
          award.business ?? 'Activation',
          IqIcons.zap,
        ),
        RewardSource.referral => ('Referral bonus', IqIcons.invite),
      };
      final detail = switch (award.source) {
        RewardSource.submission => brief?.title ?? '',
        _ => award.note ?? '',
      };
      return IqBizLedgerRow(
        columns: columns,
        semanticLabel: title,
        cells: [
          text(date.format(award.createdAt), color: IqColors.fg2),
          if (expanded) text('Reward'.toUpperCase(), color: IqColors.fg3),
          describe(icon, title, 'Reward · $detail'),
          const SizedBox.shrink(),
          text(
            hidden ? hiddenCredit : '+${naira(award.amountKobo)}',
            color: IqColors.ok,
            strong: true,
          ),
        ],
      );
    }
    final w = item.withdrawal!;
    final status = rowStatus(w);
    final returned =
        status == IqWalletRowStatus.failed ||
        status == IqWalletRowStatus.reversed;
    return IqBizLedgerRow(
      columns: columns,
      semanticLabel: 'To ${w.bankName ?? ''}',
      onTap: () => context.open(withdrawalPath(w.id)),
      cells: [
        text(date.format(w.createdAt), color: IqColors.fg2),
        if (expanded) text('Withdrawal'.toUpperCase(), color: IqColors.fg3),
        describe(IqIcons.bank, 'To ${w.bankName ?? ''}', w.reference ?? ''),
        IqMeta(kind: status.meta, label: status.label),
        text(
          hidden
              ? (returned ? hiddenAmount : hiddenDebit)
              : returned
              ? naira(w.amountKobo)
              : debit(w.amountKobo),
          color: returned ? IqColors.fg3 : IqColors.fg,
          strong: true,
        ),
      ],
    );
  }
}

class _Eye extends StatelessWidget {
  const _Eye({required this.hidden, required this.onTap});

  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      semanticLabel: hidden ? 'Show balance' : 'Hide balance',
      builder: (context, pressed) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pressed ? IqColors.panel : IqColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: IqColors.line),
        ),
        child: IqIcon(
          hidden ? IqIcons.eyeOff : IqIcons.eye,
          size: 20,
          color: IqColors.brand,
        ),
      ),
    );
  }
}
