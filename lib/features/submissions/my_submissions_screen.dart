import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/dock.dart';
import '../../ui/illustration.dart';
import '../../ui/section_title.dart';
import '../../ui/top_bar.dart';
import '../discover/app_shell.dart';
import 'submission_widgets.dart';
import 'submissions_routes.dart';
import 'submissions_state.dart';

/// B4 My submissions (35:24) with its loading (165:8524), empty (165:8608)
/// and failed to load (165:8700) states. It is the Submissions tab of the
/// app shell, which draws the dock; scroll views clear it with
/// [AppShell.contentInset].
///
/// Motion (spec 6.29, 6.31 to 6.33): the first load waits behind
/// LoadingGate; when the list lands the greeting crossfades in and the
/// titles and rows arrive 40 ms apart, each status marker wiping 120 ms
/// after its row and each hairline with its row. A row's status flies into
/// the detail's header. Try again sends the banner up and waits again; a
/// failed retry brings the banner back with the error haptic. Tapping the
/// lit tab scrolls the list to the top.
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
    final failed = state.hasError && !state.isLoading;
    final data = state.hasValue && !state.hasError ? state.value : null;
    final Widget body;
    if (failed) {
      body = const _Failed(key: ValueKey('failed'));
    } else if (data == null) {
      body = const SizedBox.shrink(key: ValueKey('loading'));
    } else if (data.items.isEmpty) {
      body = const _Empty(key: ValueKey('empty'));
    } else {
      body = _List(
        key: const ValueKey('list'),
        data: data,
        now: ref.watch(clockProvider)(),
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
                  greeting: data?.greeting ?? ' ',
                  count: '$unread',
                  showCount: unread > 0,
                  onBell: () => context.push(Routes.notifications),
                  showWallet: false,
                  showGreeting: true,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
                  child: IqBanner(
                    kind: IqBannerKind.error,
                    title: 'Couldn’t load. Check your connection.',
                    action: 'Try again',
                    visible: failed,
                    margin: const EdgeInsets.only(bottom: IqSpace.s6),
                    onAction: _retry,
                  ),
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

class _List extends StatelessWidget {
  const _List({
    super.key,
    required this.data,
    required this.now,
    required this.controller,
  });

  final MySubmissions data;
  final DateTime now;
  final ScrollController controller;

  void _open(BuildContext context, SubmissionItem item) {
    context.push(
      item.underReview ? submissionPath(item.id) : resultPath(item.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(
        IqSpace.s4,
        0,
        IqSpace.s4,
        AppShell.contentInset(context),
      ),
      children: [
        for (final group in SubmissionGroup.values)
          if (data.group(group) case final items when items.isNotEmpty) ...[
            ArriveItem(
              key: ValueKey(group),
              child: IqSectionTitle(
                showCount: true,
                title: group.title,
                count: '${items.length}',
                showLink: false,
              ),
            ),
            for (final (i, item) in items.indexed)
              ArriveItem(
                key: ValueKey(item.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (i > 0) const Hairline(),
                    SubmissionRow(
                      item: item,
                      now: now,
                      onTap: () => _open(context, item),
                    ),
                  ],
                ),
              ),
          ],
      ],
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
          Text(
            'Loading…'.toUpperCase(),
            style: IqText.mono.copyWith(color: IqColors.fg3),
          ),
          for (var i = 0; i < 4; i++) const SkeletonCard(),
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
        IqSpace.s6,
        IqSpace.s4,
        AppShell.contentInset(context),
      ),
      child: Column(
        children: [
          const IqIllustration(IqIllustrations.trophy),
          const SizedBox(height: IqSpace.s2),
          Appear(
            delay: IqDurations.stagger * 2,
            child: Text(
              'No submissions yet',
              textAlign: TextAlign.center,
              style: IqText.cardTitle.copyWith(color: IqColors.fg),
            ),
          ),
          const SizedBox(height: IqSpace.s2),
          Appear(
            delay: IqDurations.stagger * 3,
            child: Text(
              'Find a brief that fits you.',
              textAlign: TextAlign.center,
              style: IqText.body.copyWith(color: IqColors.fg2),
            ),
          ),
          const SizedBox(height: IqSpace.s2),
          IqButton(
            label: 'Browse briefs',
            kind: IqButtonKind.secondary,
            showIcon: false,
            onTap: () => context.go(Routes.home),
          ),
        ],
      ),
    );
  }
}

/// What stays under the Error banner, which sits above the gate so it can
/// slide away while a retry waits.
class _Failed extends StatelessWidget {
  const _Failed({super.key});

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
          Text(
            'Nothing to show yet',
            textAlign: TextAlign.center,
            style: IqText.cardTitle.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s2),
          Text(
            'They will show here once they load.',
            textAlign: TextAlign.center,
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
        ],
      ),
    );
  }
}
