import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../core/navigation.dart';
import '../../core/relative_time.dart';
import '../../core/responsive.dart';
import '../../data/models.dart';
import '../../data/outcomes_service.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/biz_filter_chip.dart';
import '../../ui/biz_ledger_header.dart';
import '../../ui/biz_search_field.dart';
import '../../ui/biz_segment.dart';
import '../../ui/biz_status_pill.dart';
import '../../ui/button.dart';
import '../../ui/empty_state.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/pressable.dart';
import '../../ui/web_submission_row.dart';
import '../discover/business_art.dart';
import '../drafts/drafts_state.dart';
import '../outcomes/outcomes_routes.dart';
import '../shell/tablet_page.dart';
import '../shell/tablet_popover.dart';
import '../shell/tablet_sheet.dart';
import 'brief_art.dart';
import 'submissions_state.dart';

enum _Lens { all, underReview, winners, notSelected, drafts }

enum _Sort {
  newest('Newest first'),
  oldest('Oldest first');

  const _Sort(this.label);
  final String label;
}

/// T7 · My submissions (Mobile App · tablet, 1839:136828): the won card,
/// the lens tabs (All, Under review, Winners, Not selected, Drafts), the
/// search and the sort, over the table. Portrait keeps Submission, Status
/// and Sent and opens a row as the 400 side sheet; landscape adds Reward
/// and opens it in the 360 panel beside the table, which then keeps
/// Submission and Status. Drafts list Draft, Status and Edited, plus
/// Closes in landscape.
class TabletSubmissions extends ConsumerStatefulWidget {
  const TabletSubmissions({super.key});

  @override
  ConsumerState<TabletSubmissions> createState() => _TabletSubmissionsState();
}

class _TabletSubmissionsState extends ConsumerState<TabletSubmissions> {
  final _query = TextEditingController();
  _Lens _lens = _Lens.all;
  _Sort _sort = _Sort.newest;
  bool _sorting = false;
  String? _open;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _select(SubmissionItem item) {
    if (Layout.isExpanded(context)) {
      setState(() => _open = item.id);
    } else {
      showTabletSideSheet<void>(
        context,
        builder: (context) => SubmissionPanel(id: item.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mySubmissionsProvider);
    final data = state.value;
    final drafts = ref.watch(draftItemsProvider).value ?? const <DraftItem>[];
    final now = ref.watch(clockProvider)();
    final expanded = Layout.isExpanded(context);
    final wins = data?.of(SubmissionsTab.winners) ?? const [];
    final briefsWon = {for (final w in wins) w.submission.briefId}.length;

    final segments = IqBizSegment.track(
      children: [
        for (final lens in _Lens.values)
          if (lens != _Lens.drafts || drafts.isNotEmpty)
            IqBizSegment(
              label: switch (lens) {
                _Lens.all => 'All',
                _Lens.underReview => 'Under review',
                _Lens.winners => 'Winners',
                _Lens.notSelected => 'Not selected',
                _Lens.drafts => draftsEntryLabel(drafts.length),
              },
              state: lens == _lens
                  ? IqBizSegmentState.selected
                  : IqBizSegmentState.standard,
              onTap: () => setState(() {
                _lens = lens;
                _open = null;
              }),
            ),
      ],
    );
    final search = IqBizSearchField(
      controller: _query,
      onChanged: (_) => setState(() {}),
    );
    final sort = TabletPopover(
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
    );
    final toolbar = expanded
        ? Row(
            children: [
              segments,
              const SizedBox(width: IqSpace.s6),
              Expanded(child: search),
              const SizedBox(width: IqSpace.s2),
              sort,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              segments,
              const SizedBox(height: IqSpace.s1),
              Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: IqSpace.s2),
                  sort,
                ],
              ),
            ],
          );

    final q = _query.text.trim().toLowerCase();
    bool hit(String text) => q.isEmpty || text.toLowerCase().contains(q);

    Widget body;
    if (data == null && state.hasError) {
      body = const IqEmptyState(
        figure: IqFigures.thinker,
        title: 'Couldn\'t load your submissions',
        body: 'Check your data or Wi-Fi and try again.',
      );
    } else if (data == null) {
      body = const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: IqColors.primary),
        ),
      );
    } else if (_lens == _Lens.drafts) {
      body = _DraftsTable(
        drafts: [
          for (final d in drafts)
            if (hit(d.draft.title) || hit(d.brief?.title ?? '')) d,
        ],
        now: now,
        expanded: expanded,
      );
    } else if (data.items.isEmpty) {
      body = IqEmptyState(
        title: 'No submissions yet',
        body: 'Find a brief that fits you.',
        action: 'Browse briefs',
        onAction: () => context.go(Routes.home),
      );
    } else {
      final items =
          [
            for (final i in data.items)
              if (switch (_lens) {
                    _Lens.underReview => i.underReview,
                    _Lens.winners => i.status == SubmissionStatus.winner,
                    _Lens.notSelected =>
                      i.status == SubmissionStatus.filteredOut,
                    _ => true,
                  } &&
                  (hit(i.submission.title) || hit(i.briefLine)))
                i,
          ]..sort(
            (a, b) => _sort == _Sort.newest
                ? b.submission.createdAt.compareTo(a.submission.createdAt)
                : a.submission.createdAt.compareTo(b.submission.createdAt),
          );
      final open = expanded
          ? items.where((i) => i.id == _open).firstOrNull
          : null;
      final table = _Table(
        items: items,
        now: now,
        open: open?.id,
        reward: expanded && open == null,
        sent: open == null,
        onTap: _select,
      );
      body = open == null
          ? table
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: table),
                const SizedBox(width: IqSpace.s6),
                SizedBox(
                  width: 360,
                  child: TabletCard(
                    child: SubmissionPanel(
                      id: open.id,
                      onClose: () => setState(() => _open = null),
                    ),
                  ),
                ),
              ],
            );
    }

    return TabletPage(
      title: 'My submissions',
      actions: [
        if (wins.isNotEmpty)
          _WonCard(
            label:
                '${naira(data!.wonKobo)} won from $briefsWon '
                '${briefsWon == 1 ? 'brief' : 'briefs'}',
            onTap: () => context.go(Routes.wallet),
          ),
      ],
      children: [toolbar, body],
    );
  }
}

class _WonCard extends StatelessWidget {
  const _WonCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      tactile: false,
      semanticLabel: label,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: IqSpace.s4,
          vertical: IqSpace.s2p5,
        ),
        decoration: BoxDecoration(
          color: pressed ? IqColors.panel : IqColors.card,
          borderRadius: BorderRadius.circular(IqRadius.xl),
          border: Border.all(color: IqColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IqIcon(IqIcons.medal, size: 28, color: IqColors.primary),
            const SizedBox(width: IqSpace.s3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: IqWebText.bodySmallStrong.copyWith(color: IqColors.fg),
                ),
                Text(
                  'Paid to your wallet',
                  style: IqWebText.metaCaption.copyWith(
                    color: IqColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The status a row shows and the line under it, in the product's words.
(IqBizStatusPillStatus, String?) submissionStatus(
  SubmissionItem item,
  DateTime now,
) {
  final brief = item.brief;
  return switch (item.status) {
    SubmissionStatus.pending || SubmissionStatus.scored => (
      IqBizStatusPillStatus.underReview,
      brief == null
          ? null
          : closesIn(timeLeft(brief.deadline, now), closed: !brief.isLive),
    ),
    SubmissionStatus.winner => (
      IqBizStatusPillStatus.winner,
      item.awardedAt == null
          ? null
          : 'Paid ${timeAgo(item.awardedAt!, now).toLowerCase()}',
    ),
    SubmissionStatus.filteredOut => (
      IqBizStatusPillStatus.notSelected,
      'Didn’t pass screening',
    ),
  };
}

class _Table extends StatelessWidget {
  const _Table({
    required this.items,
    required this.now,
    required this.open,
    required this.reward,
    required this.sent,
    required this.onTap,
  });

  final List<SubmissionItem> items;
  final DateTime now;
  final String? open;
  final bool reward;
  final bool sent;
  final ValueChanged<SubmissionItem> onTap;

  @override
  Widget build(BuildContext context) {
    final columns = [
      const IqBizLedgerColumn('Submission', flex: 2),
      const IqBizLedgerColumn('Status', width: 150),
      if (reward) const IqBizLedgerColumn('Reward', width: 140),
      if (sent) const IqBizLedgerColumn('Sent', width: 96, sorted: true),
    ];
    return TabletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IqBizLedgerHeader(columns: columns, trailing: 16),
          for (final item in items)
            Builder(
              builder: (context) {
                final (status, note) = submissionStatus(item, now);
                final pool = item.brief?.rewardPoolKobo;
                return IqWebSubmissionRow(
                  columns: columns,
                  title: item.submission.title,
                  brief: item.brief?.title ?? item.briefLine,
                  thumb: briefCover(item.brief),
                  status: status,
                  note: note,
                  reward: !reward
                      ? null
                      : item.status == SubmissionStatus.winner
                      ? 'Won ${naira(item.awardKobo ?? 0)}'
                      : pool == null || item.status != SubmissionStatus.pending
                      ? ' '
                      : 'Pool ${rewardPool(pool)}',
                  sent: sent ? timeAgo(item.submission.createdAt, now) : null,
                  state: item.id == open
                      ? IqWebSubmissionRowState.selected
                      : IqWebSubmissionRowState.standard,
                  onTap: () => onTap(item),
                );
              },
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
              '${items.length} ${items.length == 1 ? 'submission' : 'submissions'}',
              style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftsTable extends StatelessWidget {
  const _DraftsTable({
    required this.drafts,
    required this.now,
    required this.expanded,
  });

  final List<DraftItem> drafts;
  final DateTime now;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final columns = [
      const IqBizLedgerColumn('Draft', flex: 2),
      const IqBizLedgerColumn('Status', width: 150),
      const IqBizLedgerColumn('Edited', width: 110, sorted: true),
      if (expanded) const IqBizLedgerColumn('Closes', width: 120),
    ];
    return TabletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IqBizLedgerHeader(columns: columns, trailing: 16),
          for (final item in drafts)
            IqWebSubmissionRow(
              columns: columns,
              title: item.draft.title.isEmpty
                  ? (item.brief?.title ?? '')
                  : item.draft.title,
              brief: '${item.business} · ${stepOf(item.draft)}',
              thumb: briefCover(item.brief),
              status: IqBizStatusPillStatus.draft,
              reward: editedAgo(item.draft.editedAt, now),
              sent: expanded
                  ? closesIn(
                      timeLeft(item.brief?.deadline, now),
                      closed: !(item.brief?.isLive ?? true),
                    )
                  : null,
              onTap: () => context.open(Routes.submitTo(item.draft.briefId)),
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
              '${drafts.length} ${drafts.length == 1 ? 'draft' : 'drafts'}',
              style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
            ),
          ),
        ],
      ),
    );
  }
}

/// The submission panel (T7 side panel and side sheet): the brief, the
/// title, the status and when it was sent, the answer, what came of it and
/// the business's note, then Find your next brief.
class SubmissionPanel extends ConsumerWidget {
  const SubmissionPanel({super.key, required this.id, this.onClose});

  final String id;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(submissionItemProvider(id)).value;
    final now = ref.watch(clockProvider)();
    if (item == null) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: CircularProgressIndicator(color: IqColors.primary),
        ),
      );
    }
    final (status, note) = submissionStatus(item, now);
    final businessNote = ref.watch(businessNoteShownProvider)
        ? item.submission.note
        : null;
    final brief = item.brief;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(IqSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Submission'.toUpperCase(),
                  style: IqText.mono.copyWith(color: IqColors.fg2),
                ),
              ),
              TabletClose(onTap: onClose),
            ],
          ),
          const SizedBox(height: IqSpace.s4),
          if (brief != null)
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(IqRadius.md),
                  child: SizedBox.square(
                    dimension: 40,
                    child: briefCover(brief),
                  ),
                ),
                const SizedBox(width: IqSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (brief.businessName case final name?)
                        Text(
                          name,
                          style: IqWebText.metaCaption.copyWith(
                            color: IqColors.fg3,
                          ),
                        ),
                      Text(
                        brief.title,
                        style: IqWebText.bodySmall.copyWith(color: IqColors.fg),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: IqSpace.s4),
          Text(
            item.submission.title,
            style: IqText.title.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s3),
          Row(
            children: [
              IqBizStatusPill(status: status),
              const SizedBox(width: IqSpace.s2p5),
              Text(
                sentAgo(item.submission.createdAt, now),
                style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
              ),
            ],
          ),
          const SizedBox(height: IqSpace.s5),
          TabletCard(
            padding: const EdgeInsets.all(IqSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your answer',
                  style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
                ),
                const SizedBox(height: IqSpace.s1),
                Text(
                  item.submission.body,
                  style: IqWebText.bodyBase.copyWith(color: IqColors.fg),
                ),
              ],
            ),
          ),
          const SizedBox(height: IqSpace.s5),
          if (item.status == SubmissionStatus.filteredOut) ...[
            Text(
              'Not selected this time',
              style: IqText.bodyStrong.copyWith(color: IqColors.fg),
            ),
            if (note != null)
              Text(
                note,
                style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
              ),
            _Link(
              'See what won',
              onTap: () => context.open(leaderboardPath(item.id)),
            ),
          ] else if (item.status == SubmissionStatus.winner) ...[
            Text(
              'Won ${naira(item.awardKobo ?? 0)}',
              style: IqText.bodyStrong.copyWith(color: IqColors.fg),
            ),
            if (note != null)
              Text(
                note,
                style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
              ),
            _Link(
              'See the leaderboard',
              onTap: () => context.open(leaderboardPath(item.id)),
            ),
          ] else if (brief != null)
            _Link(
              'View the brief',
              onTap: () => context.open(Routes.brief(brief.id), extra: brief),
            ),
          if (businessNote != null) ...[
            const SizedBox(height: IqSpace.s3),
            Row(
              children: [
                ClipOval(child: businessLogo(brief?.logo, size: 20)),
                const SizedBox(width: IqSpace.s2),
                Text(
                  'A note from the business',
                  style: IqWebText.bodySmall.copyWith(color: IqColors.fg),
                ),
              ],
            ),
            const SizedBox(height: IqSpace.s2),
            Container(
              padding: const EdgeInsets.all(IqSpace.s4),
              decoration: BoxDecoration(
                color: IqColors.tint,
                borderRadius: BorderRadius.circular(IqRadius.xl),
              ),
              child: Text(
                businessNote.body,
                style: IqWebText.bodyBase.copyWith(color: IqColors.fg),
              ),
            ),
            const SizedBox(height: IqSpace.s2),
            Text(
              timeAgo(businessNote.sentAt, now),
              style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
            ),
          ],
          const SizedBox(height: IqSpace.s6),
          IqButton(
            label: 'Find your next brief',
            showIcon: false,
            width: double.infinity,
            onTap: () => context.go(Routes.home),
          ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.label, {required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      tactile: false,
      semanticLabel: label,
      builder: (context, pressed) => SizedBox(
        height: 44,
        child: Row(
          children: [
            Text(
              label,
              style: IqWebText.bodySmallStrong.copyWith(
                color: pressed ? IqColors.brandWarm : IqColors.primary,
              ),
            ),
            const SizedBox(width: IqSpace.s1),
            IqIcon(
              IqIcons.arrow,
              size: 14,
              color: pressed ? IqColors.brandWarm : IqColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
