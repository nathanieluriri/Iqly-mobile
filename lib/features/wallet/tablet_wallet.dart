import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/deadline.dart' show clockProvider;
import '../../core/navigation.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/biz_ledger_header.dart';
import '../../ui/biz_filter_chip.dart';
import '../../ui/biz_ledger_row.dart';
import '../../ui/biz_segment.dart';
import '../../ui/button.dart';
import '../../ui/empty_state.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/meta.dart';
import '../../ui/pressable.dart';
import '../../ui/wallet_row.dart';
import '../shell/tablet_page.dart';
import '../shell/tablet_popover.dart';
import '../shell/tablet_sheet.dart';
import 'activity_screen.dart'
    show ActivityFilter, ActivityStatus, ActivityWhen, activityRows;
import 'wallet_routes.dart';
import 'wallet_rows.dart';
import 'wallet_state.dart';

/// T11 · Wallet (Mobile App · tablet, 1845:81025): Bank account and
/// Withdraw (the one primary) beside the hide-balance eye, the three
/// balances sharing the width, then Activity: the All, Rewards and
/// Withdrawals segment with the Status and When filters, and the ledger.
/// The ledger has no Type column, as each row's icon and detail say it;
/// a status wraps with its reason under it.
class TabletWallet extends ConsumerStatefulWidget {
  const TabletWallet({super.key});

  @override
  ConsumerState<TabletWallet> createState() => _TabletWalletState();
}

enum _Menu { none, status, when }

class _TabletWalletState extends ConsumerState<TabletWallet> {
  ActivityTab _tab = ActivityTab.all;
  ActivityFilter _filter = const ActivityFilter();
  _Menu _menu = _Menu.none;

  void _toggle(_Menu menu) =>
      setState(() => _menu = _menu == menu ? _Menu.none : menu);

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final data = wallet.value;
    final hidden = ref.watch(walletLensProvider).hidden;
    final briefs = ref.watch(rewardBriefsProvider).value ?? const {};

    final actions = [
      _Eye(
        hidden: hidden,
        onTap: () => ref.read(walletLensProvider.notifier).toggleHidden(),
      ),
      IqButton(
        label: 'Bank account',
        kind: IqButtonKind.secondary,
        showIcon: false,
        width: _fit(context, 'Bank account', IqText.button, 172, pad: 48),
        onTap: () => context.open(bankAccountPath),
      ),
      IqButton(
        label: 'Withdraw',
        showIcon: false,
        width: _fit(context, 'Withdraw', IqText.button, 148, pad: 48),
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
          ('Earned so far', totals.totalEarnedKobo, data.earnedCaption),
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

    final now = ref.watch(clockProvider)();
    // Large text on a narrow pane folds the date into the description.
    final dated =
        MediaQuery.textScalerOf(context).scale(100) <= 115 ||
        MediaQuery.sizeOf(context).width >= 900;
    // Money never ellipsizes: the column takes its widest figure.
    final amountWidth = [
      for (final item in data.activity)
        _fit(
          context,
          hidden
              ? hiddenDebit
              : item.award != null
              ? '+${naira(item.award!.amountKobo)}'
              : debit(item.withdrawal!.amountKobo),
          IqWebText.bodySmallStrong,
          120,
        ),
    ].fold<double>(120, (a, b) => a > b ? a : b);
    final columns = [
      if (dated) const IqBizLedgerColumn('Date', width: 72, sorted: true),
      const IqBizLedgerColumn('Description', flex: 3),
      const IqBizLedgerColumn('Status', flex: 2),
      IqBizLedgerColumn('Amount', width: amountWidth, end: true),
    ];
    final date = DateFormat('d MMM');
    final kept = activityRows(data, _tab, _filter, now);
    final rows = [
      for (final item in kept)
        _row(context, item, columns, briefs, hidden, dated ? date : null),
    ];
    final segment = IqBizSegment.track(
      children: [
        for (final tab in ActivityTab.values)
          IqBizSegment(
            label: switch (tab) {
              ActivityTab.all => 'All',
              ActivityTab.rewards => 'Rewards',
              ActivityTab.withdrawals => 'Withdrawals',
            },
            state: tab == _tab
                ? IqBizSegmentState.selected
                : IqBizSegmentState.standard,
            onTap: () => setState(() => _tab = tab),
          ),
      ],
    );
    Widget menu<T>(
      _Menu which,
      String label,
      List<T> options,
      String Function(T) name,
      T selected,
      ActivityFilter Function(T) pick,
    ) => TabletPopover(
      open: _menu == which,
      onClose: () => setState(() => _menu = _Menu.none),
      anchor: IqBizFilterChip(label: label, onTap: () => _toggle(which)),
      popover: TabletMenu<T>(
        options: options,
        label: name,
        selected: selected,
        width: 200,
        onPick: (value) => setState(() {
          _filter = pick(value);
          _menu = _Menu.none;
        }),
      ),
    );
    final filters = [
      if (_tab != ActivityTab.rewards)
        menu<ActivityStatus>(
          _Menu.status,
          'Status: ${_filter.status.label}',
          ActivityStatus.values,
          (s) => s.label,
          _filter.status,
          (s) => ActivityFilter(status: s, when: _filter.when),
        ),
      menu<ActivityWhen>(
        _Menu.when,
        'When: ${_filter.when.label}',
        ActivityWhen.values,
        (w) => w.label,
        _filter.when,
        (w) => ActivityFilter(status: _filter.status, when: w),
      ),
    ];
    final toolbar = Wrap(
      spacing: IqSpace.s4,
      runSpacing: IqSpace.s3,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Activity', style: IqText.title.copyWith(color: IqColors.fg)),
            const SizedBox(width: IqSpace.s4),
            segment,
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, f) in filters.indexed) ...[
              if (i > 0) const SizedBox(width: IqSpace.s2),
              f,
            ],
          ],
        ),
      ],
    );

    return TabletPage(
      title: 'Wallet',
      actions: actions,
      children: [
        balances,
        if (data.activity.isEmpty)
          const IqEmptyState(
            figure: IqFigures.saver,
            title: 'No activity yet',
            body: 'Win a brief to start earning.',
          )
        else ...[
          toolbar,
          TabletCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqBizLedgerHeader(columns: columns),
                ...rows,
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: IqSpace.s6,
                    vertical: IqSpace.s3,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: IqColors.line)),
                  ),
                  child: Text(
                    '${rows.length} ${rows.length == 1 ? 'result' : 'results'}',
                    style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(
    BuildContext context,
    ActivityItem item,
    List<IqBizLedgerColumn> columns,
    Map<String, Brief> briefs,
    bool hidden,
    DateFormat? date,
  ) {
    Widget text(String s, {Color color = IqColors.fg, bool strong = false}) =>
        Text(
          s,
          maxLines: 1,
          softWrap: false,
          overflow: strong ? TextOverflow.visible : TextOverflow.ellipsis,
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
                maxLines: 2,
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
          if (date != null)
            text(date.format(award.createdAt), color: IqColors.fg2),
          describe(
            icon,
            title,
            [
              if (date == null) _short.format(award.createdAt),
              'Reward · $detail',
            ].join(' · '),
          ),
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
        if (date != null) text(date.format(w.createdAt), color: IqColors.fg2),
        describe(
          IqIcons.bank,
          'To ${w.destination ?? ''}',
          [
            if (date == null) _short.format(w.createdAt),
            ?w.reference,
          ].join(' · '),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IqMeta(kind: status.meta, label: status.label, maxLines: 3),
            if (returned && w.failureReason != null) ...[
              const SizedBox(height: IqSpace.s1),
              Text(
                w.failureReason!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
              ),
            ],
          ],
        ),
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

final _short = DateFormat('d MMM');

/// [text]'s width in [style] at the window's text scale plus [pad], and
/// at least [min].
double _fit(
  BuildContext context,
  String text,
  TextStyle style,
  double min, {
  double pad = 0,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width.ceilToDouble() + pad;
  painter.dispose();
  return width > min ? width : min;
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
