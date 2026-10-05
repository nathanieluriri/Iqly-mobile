import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/money.dart';
import '../../core/relative_time.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/brief_card.dart';
import '../../ui/button.dart';
import '../../ui/dock.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/list_row.dart';
import '../../ui/meta.dart';
import '../../ui/section_title.dart';
import '../../ui/segmented.dart';
import '../../ui/submission_card.dart';
import '../../ui/top_bar.dart';
import '../discover/app_shell.dart';
import '../drafts/drafts_entry.dart';
import '../drafts/drafts_state.dart';
import 'brief_art.dart';
import 'row_card.dart';
import 'submission_widgets.dart';
import 'submissions_routes.dart';
import 'submissions_state.dart';

/// B4 My submissions, the Submissions tab root: Under review (35:24),
/// Winners (324:14478) and Not selected (324:14520) as Segmented lenses,
/// with loading (165:8524), empty (165:8608) and failed to load (165:8700).
/// The shell draws the dock.
///
/// A lens switch keeps the chrome still and crossfades what is under the
/// Segmented, 200 ms. The skeleton shows on the first visit only; the list
/// is kept, so a later visit shows it at once.
class MySubmissionsScreen extends ConsumerStatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  ConsumerState<MySubmissionsScreen> createState() =>
      _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends ConsumerState<MySubmissionsScreen> {
  final _scroll = ScrollController();
  final _arrivals = ArrivalsController();
  bool _retrying = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _retry() {
    _retrying = true;
    ref.invalidate(mySubmissionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mySubmissionsProvider, (previous, next) {
      if (!_retrying || next.isLoading) return;
      _retrying = false;
      if (next.hasError) IqHaptics.error.play();
    });
    scrollToTopOnRetap(ref, context, IqDockActive.submissions, _scroll);
    final state = ref.watch(mySubmissionsProvider);
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    final data = state.value;
    final failed = data == null && state.hasError && !state.isLoading;
    final Widget body;
    if (failed) {
      body = _Failed(key: const ValueKey('failed'), onRetry: _retry);
    } else if (data == null) {
      body = const SizedBox.shrink(key: ValueKey('loading'));
    } else if (data.items.isEmpty) {
      body = const _Empty(key: ValueKey('empty'));
    } else {
      body = _Lenses(
        key: const ValueKey('list'),
        data: data,
        controller: _scroll,
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: IqColors.bg,
        body: SafeArea(
          bottom: false,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  title: 'My submissions',
                  count: '$unread',
                  showCount: unread > 0,
                  onBell: () => context.push(Routes.notifications),
                  showWallet: false,
                ),
                Expanded(
                  child: Arrivals(
                    controller: _arrivals,
                    child: LoadingGate(
                      loading: data == null && !failed,
                      skeleton: const _Loading(),
                      onOpen: (after) => _arrivals.play(after: after),
                      child: Dissolve(child: body),
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

/// The Segmented over the lens it picks. A pick crosses what sits under
/// the control into the new lens.
class _Lenses extends ConsumerWidget {
  const _Lenses({super.key, required this.data, required this.controller});

  final MySubmissions data;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(submissionsTabProvider);
    final now = ref.watch(clockProvider)();
    final drafts = (ref.watch(draftItemsProvider).value ?? const []).isNotEmpty;
    return ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(
        IqSpace.s4,
        0,
        IqSpace.s4,
        AppShell.contentInset(context),
      ),
      children: [
        Builder(
          builder: (line) => SubmissionsSegmented(
            data: data,
            selected: tab,
            onChanged: (next) {
              if (next == tab) return;
              LensCrossfade.cross(context, line: line);
              ref.read(submissionsTabProvider.notifier).select(next);
            },
          ),
        ),
        if (drafts) ...[
          const SizedBox(height: IqSpace.s3),
          const DraftsEntry(),
        ],
        for (final child in switch (tab) {
          SubmissionsTab.underReview => _underReview(context, now),
          SubmissionsTab.winners => _winners(context, now),
          SubmissionsTab.notSelected => _notSelected(context, ref, now),
        }) ...[const SizedBox(height: IqSpace.s3), child],
      ],
    );
  }

  List<Widget> _underReview(BuildContext context, DateTime now) => [
    for (final item in data.of(SubmissionsTab.underReview))
      ArriveItem(
        key: ValueKey(item.id),
        child: SubmissionCardFor(
          item: item,
          now: now,
          onTap: () => context.push(submissionPath(item.id)),
        ),
      ),
  ];

  List<Widget> _winners(BuildContext context, DateTime now) {
    final wins = data.of(SubmissionsTab.winners);
    if (wins.isEmpty) return const [];
    final briefs = {for (final w in wins) w.submission.briefId}.length;
    return [
      ArriveItem(
        key: const ValueKey('won'),
        child: RowCard(
          radius: IqRadius.xl2,
          child: IqListRow(
            label:
                '${naira(data.wonKobo)} won from $briefs '
                '${briefs == 1 ? 'brief' : 'briefs'}',
            description: 'Paid to your wallet',
            icon: IqIcons.bank,
            divider: false,
            onTap: () => context.go(Routes.wallet),
          ),
        ),
      ),
      for (final item in wins)
        ArriveItem(
          key: ValueKey(item.id),
          child: SubmissionCardFor(
            item: item,
            now: now,
            onTap: () => context.push(resultPath(item.id)),
          ),
        ),
    ];
  }

  List<Widget> _notSelected(BuildContext context, WidgetRef ref, DateTime now) {
    final briefs = ref.watch(tryAnotherBriefsProvider).value ?? const [];
    return [
      for (final item in data.of(SubmissionsTab.notSelected))
        ArriveItem(
          key: ValueKey(item.id),
          child: SubmissionCardFor(
            item: item,
            now: now,
            onTap: () => context.push(resultPath(item.id)),
          ),
        ),
      if (briefs.isNotEmpty) ...[
        const ArriveItem(
          key: ValueKey('try'),
          child: IqSectionTitle(
            title: 'Try another brief',
            showCount: false,
            showLink: false,
          ),
        ),
        for (final brief in briefs)
          ArriveItem(
            key: ValueKey('try-${brief.id}'),
            child: IqBriefCard(
              kind: IqBriefCardKind.row,
              brand: brief.businessName ?? 'Private business',
              title: brief.title,
              cover: briefCover(brief),
              logo: briefLogo(brief),
              meta: rowBriefMeta(brief, now),
              onTap: () => context.push(Routes.brief(brief.id), extra: brief),
            ),
          ),
      ],
    ];
  }
}

/// The Segmented with each lens's count; the counts wait for the load.
class SubmissionsSegmented extends StatelessWidget {
  const SubmissionsSegmented({
    super.key,
    this.data,
    this.selected = SubmissionsTab.underReview,
    this.onChanged,
  });

  final MySubmissions? data;
  final SubmissionsTab selected;
  final ValueChanged<SubmissionsTab>? onChanged;

  String _label(SubmissionsTab tab) {
    final data = this.data;
    return data == null ? tab.label : '${tab.label} · ${data.count(tab)}';
  }

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return IqSegmented(
      option1: _label(SubmissionsTab.underReview),
      option2: _label(SubmissionsTab.winners),
      option3: _label(SubmissionsTab.notSelected),
      selected: IqSegmentedSelected.values[selected.index],
      onChanged: onChanged == null
          ? null
          : (s) => onChanged(SubmissionsTab.values[s.index]),
    );
  }
}

/// An Exp/SubmissionCard for [item] as the B4 lenses fill it.
class SubmissionCardFor extends StatelessWidget {
  const SubmissionCardFor({
    super.key,
    required this.item,
    required this.now,
    this.onTap,
  });

  final SubmissionItem item;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brief = item.brief;
    final sent = sentAgo(item.submission.createdAt, now);
    final (status, label, kind, line) = switch (item.status) {
      SubmissionStatus.pending || SubmissionStatus.scored => (
        IqSubmissionCardStatus.underReview,
        brief == null
            ? 'Under review'
            : closesIn(timeLeft(brief.deadline, now), closed: !brief.isLive),
        brief == null ? IqMetaKind.time : IqMetaKind.deadline,
        sent,
      ),
      SubmissionStatus.winner => (
        IqSubmissionCardStatus.winner,
        'Won ${nairaShort(item.awardKobo ?? 0)}',
        IqMetaKind.done,
        timeAgo(item.awardedAt ?? item.submission.createdAt, now),
      ),
      SubmissionStatus.filteredOut => (
        IqSubmissionCardStatus.notSelected,
        'Didn’t pass screening',
        IqMetaKind.plain,
        sent,
      ),
    };
    return IqSubmissionCard(
      status: status,
      statusLabel: label,
      statusKind: kind,
      title: item.submission.title,
      brief: item.briefLine,
      sent: line,
      cover: briefCover(brief),
      logo: briefLogo(brief),
      onTap: onTap,
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SubmissionsSegmented(),
          for (var i = 0; i < 3; i++) ...[
            const SizedBox(height: IqSpace.s3),
            const SkeletonSubmissionCard(),
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        IqSpace.s4,
        121 + IqSpace.s6,
        IqSpace.s4,
        AppShell.contentInset(context),
      ),
      child: Column(
        children: [
          const IqFigure(IqFigures.writer, width: 188, arrive: true),
          const SizedBox(height: IqSpace.s3),
          Text(
            'No submissions yet',
            textAlign: TextAlign.center,
            style: IqText.title.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s3),
          Text(
            'Find a brief that fits you.',
            textAlign: TextAlign.center,
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
          const SizedBox(height: IqSpace.s3),
          IqButton(
            label: 'Browse briefs',
            showIcon: false,
            width: 200,
            onTap: () => context.push(Routes.pickBrief),
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        IqSpace.s4,
        0,
        IqSpace.s4,
        AppShell.contentInset(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IqBanner(
            kind: IqBannerKind.error,
            title: 'Couldn’t load. Check your connection.',
            action: 'Try again',
            onAction: onRetry,
          ),
          const SizedBox(height: IqSpace.s4 + IqSpace.s8),
          const Center(child: IqFigure(IqFigures.thinker, width: 188)),
          const SizedBox(height: IqSpace.s3),
          Text(
            'Couldn\'t load your submissions',
            textAlign: TextAlign.center,
            style: IqText.title.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s3),
          Text(
            'Check your data or Wi-Fi and try again.',
            textAlign: TextAlign.center,
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
        ],
      ),
    );
  }
}
