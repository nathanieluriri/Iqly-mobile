import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/money.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../data/device.dart';
import '../../data/models.dart';
import '../../data/submit_service.dart' show briefAudienceProvider;
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/bookmark.dart';
import '../../ui/button.dart';
import '../../ui/switch.dart';
import '../../ui/tablet_action_bar.dart';
import '../../ui/urgency.dart';
import '../../core/brief_labels.dart';
import '../shell/tablet_page.dart';
import '../submissions/submissions_routes.dart';
import 'business_art.dart';
import 'discover_state.dart';
import 'discover_widgets.dart';

/// What the one action on a brief is: start, view what was sent, or why it
/// cannot be started.
({String label, bool disabled, bool secondary, VoidCallback onTap}) briefAction(
  BuildContext context,
  WidgetRef ref,
  Brief brief,
) {
  final now = ref.watch(clockProvider)();
  final left = timeLeft(brief.deadline, now);
  final closed = !brief.isLive || (left != null && left <= Duration.zero);
  final outside = brief.inAudience == false && ref.watch(briefAudienceProvider);
  final full = brief.spotsLeft == 0;
  final sent = ref.watch(briefSubmissionProvider(brief.id));
  if (sent != null) {
    return (
      label: 'View your submission',
      disabled: false,
      secondary: true,
      onTap: () => context.open(submissionPath(sent)),
    );
  }
  return (
    label: closed
        ? 'Closed · results soon'
        : outside
        ? 'For a different audience'
        : full
        ? 'Capacity reached'
        : 'Start your submission',
    disabled: closed || outside || full,
    secondary: false,
    onTap: () => context.open(Routes.submitTo(brief.id)),
  );
}

/// T5 · Brief detail (Mobile App · tablet, 1832:39549). Landscape: the
/// reading column (the cover, the eyebrow, the ask, who posted it and the
/// brief) beside the 320 panel with the reward, the deadline, the spots
/// and the facts, the one primary, Save and Remind me. Portrait: one
/// reading column with that panel inline under the ask and
/// Exp/Tablet/ActionBar pinned at the foot with the bookmark and the
/// primary.
///
/// Figma over the data: the frames split the brief into Overview, The
/// problem, What to send, How it's judged and Timeline; the brief carries
/// one body, so it reads as one block, and Accepts (not in the brief) is
/// left out of the facts.
class TabletBriefDetail extends ConsumerWidget {
  const TabletBriefDetail({super.key, required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = Layout.isExpanded(context);
    final now = ref.watch(clockProvider)();
    final left = timeLeft(brief.deadline, now);
    final saved =
        ref.watch(savedBriefsProvider).value?.any((b) => b.id == brief.id) ??
        false;
    final action = briefAction(context, ref, brief);
    final reading = <Widget>[
      ClipRRect(
        borderRadius: BorderRadius.circular(IqRadius.xl2),
        child: SizedBox(
          height: expanded ? 300 : 290,
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: 646,
              height: 290,
              child: businessCover(brief.cover),
            ),
          ),
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${brief.tier.label} · ${brief.category.label}'.toUpperCase(),
            style: IqText.mono.copyWith(color: IqColors.fg2),
          ),
          const SizedBox(height: IqSpace.s3),
          Text(brief.title, style: IqLandText.h2.copyWith(color: IqColors.fg)),
          const SizedBox(height: IqSpace.s3),
          Row(
            children: [
              ClipOval(child: businessLogo(brief.logo, size: 36)),
              const SizedBox(width: IqSpace.s3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Posted by',
                    style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
                  ),
                  Text(
                    businessLabel(brief),
                    style: IqWebText.bodySmallStrong.copyWith(
                      color: IqColors.fg,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      if (!expanded)
        _Panel(brief: brief, now: now, left: left, wide: true, saved: saved),
      Text(brief.body, style: IqLandText.body.copyWith(color: IqColors.fg)),
      _Business(brief: brief),
    ];
    final crumbs = [
      TabletCrumb('Discover', () => context.go(Routes.home)),
      TabletCrumb(brief.title),
    ];
    if (!expanded) {
      return TabletPage(
        crumbs: crumbs,
        bottomBar: IqTabletActionBar(
          title: rewardPool(brief.rewardPoolKobo),
          caption: [
            closesIn(left, closed: !brief.isLive),
            if (brief.spotsLeft != null) spotsLeftLabel(brief),
          ].join(' · '),
          actions: [
            if (Flags.savedBriefs)
              IqBookmark(
                state: saved ? IqBookmarkState.on : IqBookmarkState.off,
                onChanged: (state) => ref
                    .read(savedBriefsProvider.notifier)
                    .setSaved(brief, state == IqBookmarkState.on),
              ),
            IqButton(
              label: action.label,
              kind: action.secondary
                  ? IqButtonKind.secondary
                  : IqButtonKind.primary,
              disabled: action.disabled,
              width: 248,
              onTap: action.onTap,
            ),
          ],
        ),
        children: reading,
      );
    }
    return TabletPage(
      crumbs: crumbs,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, w) in reading.indexed) ...[
                    if (i > 0) const SizedBox(height: IqSpace.s8),
                    w,
                  ],
                ],
              ),
            ),
            const SizedBox(width: IqSpace.s12),
            SizedBox(
              width: 320,
              child: _Panel(
                brief: brief,
                now: now,
                left: left,
                wide: false,
                saved: saved,
                action: action,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The reward panel: the pool, the deadline, the spots and the facts.
/// Portrait lays the reward beside the facts; landscape stacks them and
/// adds the action and Save.
class _Panel extends ConsumerWidget {
  const _Panel({
    required this.brief,
    required this.now,
    required this.left,
    required this.wide,
    required this.saved,
    this.action,
  });

  final Brief brief;
  final DateTime now;
  final Duration? left;
  final bool wide;
  final bool saved;
  final ({String label, bool disabled, bool secondary, VoidCallback onTap})?
  action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closed = !brief.isLive;
    final rule = brief.winnerRule;
    final total = brief.spotsTotal;
    final spotsLeft = brief.spotsLeft;
    final reward = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reward pool'.toUpperCase(),
          style: IqText.mono.copyWith(color: IqColors.fg2),
        ),
        const SizedBox(height: IqSpace.s2),
        Text(
          rewardPool(brief.rewardPoolKobo),
          style: IqText.figure.copyWith(color: IqColors.brand),
        ),
        if (rule != null) ...[
          const SizedBox(height: IqSpace.s2),
          Text(rule, style: IqWebText.bodySmall.copyWith(color: IqColors.fg2)),
        ],
        const SizedBox(height: IqSpace.s4),
        IqUrgency(
          text: closesIn(left, closed: closed),
          tone: urgencyTone(left, closed: closed),
        ),
        if (spotsLeft != null && total != null && total > 0) ...[
          const SizedBox(height: IqSpace.s4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: spotsLeftLabel(brief),
                  style: IqWebText.bodySmallStrong.copyWith(
                    color: IqColors.brand,
                  ),
                ),
                TextSpan(
                  text: ' · ${total - spotsLeft} of $total taken',
                  style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
                ),
              ],
            ),
          ),
          const SizedBox(height: IqSpace.s2),
          ClipRRect(
            borderRadius: BorderRadius.circular(IqRadius.full),
            child: LinearProgressIndicator(
              value: (total - spotsLeft) / total,
              minHeight: 6,
              color: IqColors.accentStrong,
              backgroundColor: IqColors.tintStrong,
            ),
          ),
        ],
      ],
    );
    final deadline = brief.deadline;
    final facts = Column(
      children: [
        if (deadline != null) _Fact('Closes', _closes(deadline, now)),
        if (brief.minutes case final m?) _Fact('Takes', 'About $m min'),
        _Fact('Tier', brief.tier.label),
      ],
    );
    final remind = _Remind(brief: brief, saved: saved, left: left);
    final action = this.action;
    return Container(
      padding: const EdgeInsets.all(IqSpace.s6),
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(IqRadius.xl2),
        border: Border.all(color: IqColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: reward),
                const SizedBox(width: IqSpace.s8),
                Expanded(child: facts),
              ],
            )
          else ...[
            reward,
            const SizedBox(height: IqSpace.s4),
            facts,
          ],
          if (action != null) ...[
            const SizedBox(height: IqSpace.s6),
            IqButton(
              label: action.label,
              kind: action.secondary
                  ? IqButtonKind.secondary
                  : IqButtonKind.primary,
              disabled: action.disabled,
              width: double.infinity,
              onTap: action.onTap,
            ),
            if (Flags.savedBriefs) ...[
              const SizedBox(height: IqSpace.s5),
              IqButton(
                label: saved ? 'Saved' : 'Save',
                kind: IqButtonKind.secondary,
                showIcon: false,
                width: double.infinity,
                onTap: () => ref
                    .read(savedBriefsProvider.notifier)
                    .setSaved(brief, !saved),
              ),
            ],
          ],
          if (remind.shown) remind,
        ],
      ),
    );
  }

  static String _closes(DateTime deadline, DateTime now) {
    final day = DateUtils.dateOnly(deadline);
    final today = DateUtils.dateOnly(now);
    final time = DateFormat('h:mm a').format(deadline).toLowerCase();
    if (day == today) return 'Today at $time';
    if (day == today.add(const Duration(days: 1))) return 'Tomorrow at $time';
    return '${DateFormat('d MMM').format(deadline)} at $time';
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: IqSpace.s2p5),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: IqColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: IqWebText.bodySmall.copyWith(color: IqColors.fg3),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: IqWebText.bodySmall.copyWith(color: IqColors.fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Remind me, for a saved brief still open (Flags.closeReminders).
class _Remind extends ConsumerWidget {
  const _Remind({required this.brief, required this.saved, required this.left});

  final Brief brief;
  final bool saved;
  final Duration? left;

  bool get shown =>
      Flags.closeReminders &&
      saved &&
      brief.isLive &&
      left != null &&
      left! > Duration.zero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(closeRemindersProvider).value ?? const {};
    return Padding(
      padding: const EdgeInsets.only(top: IqSpace.s6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remind me',
                  style: IqWebText.bodySmallStrong.copyWith(color: IqColors.fg),
                ),
                Text(
                  'An hour before close',
                  style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
                ),
              ],
            ),
          ),
          IqSwitch(
            semanticLabel: 'Remind me',
            state: reminders.contains(brief.id)
                ? IqSwitchState.on
                : IqSwitchState.off,
            onChanged: (state) async {
              final on = state == IqSwitchState.on;
              await ref
                  .read(closeRemindersProvider.notifier)
                  .setReminder(brief.id, on);
              if (on) {
                await ref
                    .read(deviceServiceProvider)
                    .requestNotificationPermission();
              }
            },
          ),
        ],
      ),
    );
  }
}

/// The business: its logo, name and how many live briefs it has here.
class _Business extends ConsumerWidget {
  const _Business({required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = brief.businessName;
    if (name == null) return const SizedBox.shrink();
    final live = [
      for (final b in ref.watch(discoverFeedProvider).value?.briefs ?? [])
        if (b.isLive && b.businessName == name) b,
    ].length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('The business', style: IqText.title.copyWith(color: IqColors.fg)),
        const SizedBox(height: IqSpace.s4),
        Row(
          children: [
            ClipOval(child: businessLogo(brief.logo, size: 48)),
            const SizedBox(width: IqSpace.s3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: IqText.cardTitle.copyWith(color: IqColors.fg),
                ),
                if (live > 0)
                  Text(
                    '$live live ${live == 1 ? 'brief' : 'briefs'} on iQLY',
                    style: IqWebText.bodySmall.copyWith(color: IqColors.fg2),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
