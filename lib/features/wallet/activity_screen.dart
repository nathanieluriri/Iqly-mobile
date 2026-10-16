import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/models.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/chip.dart';
import '../../ui/segmented.dart';
import '../../ui/text_link.dart';
import '../../ui/top_bar.dart';
import '../../ui/icon.dart';
import 'wallet_overview.dart' show NoActivity;
import 'wallet_routes.dart';
import 'wallet_rows.dart';
import 'wallet_sheet.dart';
import 'wallet_state.dart';

enum ActivityStatus {
  any('Any'),
  pending('Pending'),
  reversed('Reversed'),
  completed('Completed'),
  failed('Failed');

  const ActivityStatus(this.label);

  final String label;
}

enum ActivityWhen {
  days30('30 days', 30),
  days90('90 days', 90),
  allTime('All time', null);

  const ActivityWhen(this.label, this.days);

  final String label;
  final int? days;
}

class ActivityFilter {
  const ActivityFilter({
    this.status = ActivityStatus.any,
    this.when = ActivityWhen.allTime,
  });

  final ActivityStatus status;
  final ActivityWhen when;

  bool keeps(ActivityItem item, DateTime now) {
    final days = when.days;
    if (days != null && now.difference(item.at).inDays >= days) return false;
    if (status == ActivityStatus.any) return true;
    final w = item.withdrawal;
    if (w == null) return false;
    return switch (status) {
      ActivityStatus.pending => w.onHold,
      ActivityStatus.reversed => w.status == WithdrawalStatus.reversed,
      ActivityStatus.completed => w.status == WithdrawalStatus.completed,
      ActivityStatus.failed => w.status == WithdrawalStatus.failed,
      ActivityStatus.any => true,
    };
  }
}

/// The rows of [tab] that [filter] keeps, newest first.
List<ActivityItem> activityRows(
  WalletData data,
  ActivityTab tab,
  ActivityFilter filter,
  DateTime now,
) => [
  for (final item in data.activity)
    if ((tab == ActivityTab.all ||
            (tab == ActivityTab.rewards) == (item.award != null)) &&
        filter.keeps(item, now))
      item,
];

/// B5 · Activity · All (343:16290), Rewards (331:15107) and Withdrawals
/// (343:16311): one sub page. The segmented control slides the list over
/// to the picked lens under still chrome (LensSlide; a filter only
/// crossfades); the Filter link opens the Filter activity sheet
/// (332:15891).
///
/// Figma slips not copied: the frames' result counts (5, 2, 3) and the
/// Kudi Box and referral rows under Earlier; counts and groups come from
/// the rows.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key, this.initial = ActivityTab.all});

  final ActivityTab initial;

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  late ActivityTab _tab = widget.initial;
  ActivityFilter _filter = const ActivityFilter();

  Future<void> _openFilter() async {
    final picked = await showIqSheet<ActivityFilter>(
      context,
      (context) => FilterActivitySheet(tab: _tab, initial: _filter),
      scrim: IqScrim.sheet,
    );
    if (picked != null && mounted) setState(() => _filter = picked);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(walletProvider).value;
    final now = ref.watch(clockProvider)();
    final briefs = ref.watch(rewardBriefsProvider).value ?? const {};
    final hidden = ref.watch(walletLensProvider).hidden;
    final rows = data == null
        ? const <ActivityItem>[]
        : activityRows(data, _tab, _filter, now);
    final week = [
      for (final r in rows)
        if (now.difference(r.at).inDays < 7) r,
    ];
    final earlier = [
      for (final r in rows)
        if (now.difference(r.at).inDays >= 7) r,
    ];

    Widget group(String label, List<ActivityItem> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: IqText.smallStrong.copyWith(color: IqColors.fg2)),
        const SizedBox(height: IqSpace.s3),
        ActivityCard(
          children: [
            for (final (i, item) in items.indexed)
              WalletActivityRow(
                key: ValueKey(item.key),
                item: item,
                briefs: briefs,
                now: now,
                hidden: hidden,
                divider: i < items.length - 1,
              ),
          ],
        ),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          bottom: false,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: switch (_tab) {
                    ActivityTab.all => 'Activity',
                    ActivityTab.rewards => 'Rewards',
                    ActivityTab.withdrawals => 'Withdrawals',
                  },
                  onBack: () => leaveWallet(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    IqSpace.s2,
                    IqSpace.s4,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IqSegmented(
                        option1: 'All',
                        option2: 'Rewards',
                        option3: 'Withdrawals',
                        selected: IqSegmentedSelected.values[_tab.index],
                        onChanged: (option) => setState(
                          () => _tab = ActivityTab.values[option.index],
                        ),
                      ),
                      const SizedBox(height: IqSpace.s3),
                      SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 80),
                              child: IqTextLink(
                                label: 'Filter',
                                icon: IqIcons.filter,
                                onTap: _openFilter,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${rows.length} results',
                              style: IqText.small.copyWith(color: IqColors.fg3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LensSlide(
                    index: _tab.index,
                    contentKey: (_filter.status, _filter.when),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        IqSpace.s4,
                        IqSpace.s3,
                        IqSpace.s4,
                        MediaQuery.viewPaddingOf(context).bottom + IqSpace.s6,
                      ),
                      children: [
                        if (data != null && rows.isEmpty)
                          const ActivityCard(children: [NoActivity()]),
                        if (week.isNotEmpty) group('This week', week),
                        if (week.isNotEmpty && earlier.isNotEmpty)
                          const SizedBox(height: IqSpace.s3),
                        if (earlier.isNotEmpty) group('Earlier', earlier),
                      ],
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

/// B5 · Filter activity sheet (332:15891): one status and one time span;
/// the button counts what the pick would show.
class FilterActivitySheet extends ConsumerStatefulWidget {
  const FilterActivitySheet({
    super.key,
    required this.tab,
    required this.initial,
  });

  final ActivityTab tab;
  final ActivityFilter initial;

  @override
  ConsumerState<FilterActivitySheet> createState() =>
      _FilterActivitySheetState();
}

class _FilterActivitySheetState extends ConsumerState<FilterActivitySheet> {
  late ActivityStatus _status = widget.initial.status;
  late ActivityWhen _when = widget.initial.when;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(walletProvider).value;
    final now = ref.watch(clockProvider)();
    final filter = ActivityFilter(status: _status, when: _when);
    final count = data == null
        ? 0
        : activityRows(data, widget.tab, filter, now).length;

    Widget label(String text) =>
        Text(text, style: IqText.smallStrong.copyWith(color: IqColors.fg2));

    return WalletSheet(
      children: [
        IqTopBar(
          variant: IqTopBarVariant.sheet,
          title: 'Filter activity',
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
              label('Status'),
              const SizedBox(height: 10),
              Wrap(
                spacing: IqSpace.s2,
                runSpacing: IqSpace.s2,
                children: [
                  for (final s in ActivityStatus.values)
                    IqChip(
                      label: s.label,
                      state: s == _status
                          ? IqChipState.selected
                          : IqChipState.standard,
                      onChanged: (_) => setState(() => _status = s),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              label('When'),
              const SizedBox(height: 10),
              Wrap(
                spacing: IqSpace.s2,
                runSpacing: IqSpace.s2,
                children: [
                  for (final w in ActivityWhen.values)
                    IqChip(
                      label: w.label,
                      state: w == _when
                          ? IqChipState.selected
                          : IqChipState.standard,
                      onChanged: (_) => setState(() => _when = w),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              IqButton(
                label: 'Show $count results',
                showIcon: false,
                width: double.infinity,
                rollLabel: true,
                onTap: () => Navigator.of(context).pop(filter),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
