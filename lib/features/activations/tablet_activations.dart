import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../data/activations_data.dart';
import '../../theme/theme.dart';
import '../../ui/biz_filter_chip.dart';
import '../../ui/biz_ledger_header.dart';
import '../../ui/biz_segment.dart';
import '../../ui/button.dart';
import '../../ui/empty_state.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/urgency.dart';
import '../../ui/web_activation_row.dart';
import '../shell/tablet_page.dart';
import '../shell/tablet_popover.dart';
import '../shell/tablet_sheet.dart';
import 'activation_format.dart';
import 'activations_routes.dart';
import 'activations_state.dart';

enum _Lens { all, active, done }

enum _Sort {
  closing('Closing soonest'),
  reward('Biggest reward');

  const _Sort(this.label);
  final String label;
}

/// T10 · Activations (Mobile App · tablet, 1843:48473): My activations
/// over the lens tabs and the table. Portrait keeps Activation, Reward and
/// Closes; landscape adds Spots, as at 1024. A row opens the activation.
class TabletActivations extends ConsumerStatefulWidget {
  const TabletActivations({super.key});

  @override
  ConsumerState<TabletActivations> createState() => _TabletActivationsState();
}

class _TabletActivationsState extends ConsumerState<TabletActivations> {
  _Lens _lens = _Lens.all;
  _Sort _sort = _Sort.closing;
  bool _sorting = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activationsProvider);
    final now = ref.watch(clockProvider)();
    final expanded = Layout.isExpanded(context);
    final all = state.value ?? const <Activation>[];
    final open = [
      for (final a in all)
        if (!a.credited && !a.closedAt(now)) a,
    ];
    final active = [
      for (final a in all)
        if (a.inFlight) a,
    ];
    final done = [
      for (final a in all)
        if (a.credited) a,
    ];
    final shown =
        switch (_lens) {
          _Lens.all => open,
          _Lens.active => active,
          _Lens.done => done,
        }..sort(
          (a, b) => _sort == _Sort.closing
              ? a.closesAt.compareTo(b.closesAt)
              : b.rewardKobo.compareTo(a.rewardKobo),
        );
    final lead = leadActivation(all);

    final columns = [
      const IqBizLedgerColumn('Activation', flex: 3),
      const IqBizLedgerColumn('Reward', width: 92),
      if (expanded) const IqBizLedgerColumn('Spots', width: 116),
      const IqBizLedgerColumn('Closes', width: 150),
    ];

    final toolbar = Row(
      children: [
        IqBizSegment.track(
          children: [
            for (final lens in _Lens.values)
              IqBizSegment(
                label: switch (lens) {
                  _Lens.all => 'All · ${open.length}',
                  _Lens.active => 'Active · ${active.length}',
                  _Lens.done => 'Done',
                },
                state: lens == _lens
                    ? IqBizSegmentState.selected
                    : IqBizSegmentState.standard,
                onTap: () => setState(() => _lens = lens),
              ),
          ],
        ),
        const Spacer(),
        TabletPopover(
          open: _sorting,
          onClose: () => setState(() => _sorting = false),
          anchor: IqBizFilterChip(
            label: 'Sort: ${_sort.label}',
            onTap: () => setState(() => _sorting = !_sorting),
          ),
          popover: TabletMenu<_Sort>(
            options: _Sort.values,
            label: (s) => s.label,
            selected: _sort,
            onPick: (s) => setState(() {
              _sort = s;
              _sorting = false;
            }),
          ),
        ),
      ],
    );

    Widget body;
    if (state.value == null && state.hasError) {
      body = const IqEmptyState(
        figure: IqFigures.thinker,
        title: 'Couldn’t load activations',
        body: 'Check your data or Wi-Fi and try again.',
      );
    } else if (state.value == null) {
      body = const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: IqColors.primary),
        ),
      );
    } else if (shown.isEmpty) {
      body = const IqEmptyState(
        figure: IqFigures.shrug,
        title: 'No activations right now',
        body: 'New activations land here.',
      );
    } else {
      body = TabletCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IqBizLedgerHeader(columns: columns, trailing: 16),
            for (final a in shown)
              IqWebActivationRow(
                columns: columns,
                business: a.business,
                title: a.title,
                status: progressLine(a),
                statusWarm: a.inFlight && a.confirmed < a.steps.length,
                cover: activationCoverArt(a),
                logo: activationLogoArt(a),
                reward: reward(a),
                spots: expanded
                    ? '${a.spotsLeft} ${a.spotsLeft == 1 ? 'spot' : 'spots'} left'
                    : null,
                spotsLow: closingSoon(a, now),
                closes: closingSoon(a, now)
                    ? IqUrgency(
                        text: deadlineText(a, now),
                        tone: IqUrgencyTone.warm,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const IqIcon(
                            IqIcons.timer,
                            size: 14,
                            color: IqColors.brand,
                          ),
                          const SizedBox(width: IqSpace.s1p5),
                          Flexible(
                            child: Text(
                              deadlineText(a, now),
                              style: IqWebText.bodySmall.copyWith(
                                color: IqColors.fg,
                              ),
                            ),
                          ),
                        ],
                      ),
                onTap: () => context.open(activationPath(a.id)),
              ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: IqSpace.s6,
                vertical: IqSpace.s3,
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: IqColors.line)),
              ),
              child: Text(
                '${shown.length} ${shown.length == 1 ? 'activation' : 'activations'}',
                style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
              ),
            ),
          ],
        ),
      );
    }

    return TabletPage(
      title: 'Activations',
      subtitle:
          'Paid to your iQLY wallet once the business confirms, usually '
          'within 24 hours.',
      children: [
        if (lead != null) _Mine(lead: lead, now: now),
        toolbar,
        body,
      ],
    );
  }
}

/// My activations: the run furthest along and what it waits on.
class _Mine extends StatelessWidget {
  const _Mine({required this.lead, required this.now});

  final Activation lead;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final next = lead.confirmed + 1;
    final canProve =
        lead.canProveAt(now) &&
        proofHeldBack(lead, now) == null &&
        next <= lead.steps.length;
    final waiting = lead.waitingSince != null;
    return TabletCard(
      padding: const EdgeInsets.symmetric(
        horizontal: IqSpace.s4,
        vertical: IqSpace.s3,
      ),
      child: Row(
        children: [
          const IqIcon(IqIcons.zap, size: 28, color: IqColors.brand),
          const SizedBox(width: IqSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My activations',
                  style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
                ),
                Text(
                  myActivationsLine(lead),
                  style: IqWebText.bodySmallStrong.copyWith(color: IqColors.fg),
                ),
                if (waiting)
                  Text(
                    'Step $next not confirmed yet · ${waitingCount(lead, now)}',
                    style: IqWebText.metaCaption.copyWith(
                      color: IqColors.accentStrong,
                    ),
                  ),
              ],
            ),
          ),
          if (canProve)
            IqButton(
              label: 'Upload proof of step $next',
              kind: IqButtonKind.secondary,
              showIcon: false,
              width: 220,
              height: 52,
              onTap: () => context.open(proofPath(lead.id)),
            )
          else
            IqButton(
              label: 'Open',
              kind: IqButtonKind.secondary,
              showIcon: false,
              width: 120,
              onTap: () => context.open(activationPath(lead.id)),
            ),
        ],
      ),
    );
  }
}
