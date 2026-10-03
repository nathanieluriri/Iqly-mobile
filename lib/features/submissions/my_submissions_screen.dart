import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
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
class MySubmissionsScreen extends ConsumerWidget {
  const MySubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mySubmissionsProvider);
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    final data = state.hasValue && !state.hasError ? state.value : null;
    final Widget body;
    if (data == null) {
      body = state.hasError && !state.isLoading
          ? _Failed(
              key: const ValueKey('failed'),
              onRetry: () => ref.invalidate(mySubmissionsProvider),
            )
          : const _Loading(key: ValueKey('loading'));
    } else if (data.items.isEmpty) {
      body = const _Empty(key: ValueKey('empty'));
    } else {
      body = _List(
        key: const ValueKey('list'),
        data: data,
        now: ref.watch(clockProvider)(),
      );
    }
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
                  title: 'My submissions',
                  greeting: data?.greeting ?? ' ',
                  count: '$unread',
                  showCount: unread > 0,
                  onBell: () => context.push(Routes.notifications),
                ),
                Expanded(child: Dissolve(child: body)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({super.key, required this.data, required this.now});

  final MySubmissions data;
  final DateTime now;

  void _open(BuildContext context, SubmissionItem item) {
    context.push(
      item.underReview ? submissionPath(item.id) : resultPath(item.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        IqSpace.s4,
        0,
        IqSpace.s4,
        AppShell.contentInset(context),
      ),
      children: [
        for (final group in SubmissionGroup.values)
          if (data.group(group) case final items when items.isNotEmpty) ...[
            IqSectionTitle(
              title: group.title,
              count: '${items.length}',
              showLink: false,
            ),
            for (final (i, item) in items.indexed) ...[
              if (i > 0) const Hairline(),
              SubmissionRow(
                item: item,
                now: now,
                onTap: () => _open(context, item),
              ),
            ],
          ],
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({super.key});

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
          Text(
            'No submissions yet',
            textAlign: TextAlign.center,
            style: IqText.cardTitle.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s2),
          Text(
            'Find a brief that fits you.',
            textAlign: TextAlign.center,
            style: IqText.body.copyWith(color: IqColors.fg2),
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
          const SizedBox(height: IqSpace.s6),
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
