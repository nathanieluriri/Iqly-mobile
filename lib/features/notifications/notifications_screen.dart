import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/empty_state.dart';
import '../../ui/illustration.dart';
import '../../ui/notification.dart';
import '../../ui/section_title.dart';
import '../../ui/skeleton.dart';
import '../../ui/top_bar.dart';
import '../discover/discover_widgets.dart';
import '../more/more_widgets.dart';
import 'notifications_state.dart';
import 'tablet_notifications.dart';

/// B6 · Notifications (39:24) and its empty state (39:180), a sub page from
/// the bell and from More. Deadlines and spots read brief data, the result,
/// the rewards and the payouts the ledger and withdrawals; seeing the feed
/// clears the bell on every tab. A payout, result or deadline row opens its
/// Notification sub page first; the row reads as read once that page shows.
///
/// Motion (MOTION-SPEC §7.5): the rows arrive the first time the feed shows
/// in a session. Loading shows skeleton rows after 300 ms; a failed load
/// shows the error banner and Try again.
///
/// Where the build parts from the frame, on purpose: the feed runs newest
/// first (the frame lists today's rows 2h, 1h, 5h).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _seen = false;

  /// A visit reads the feed again behind the rows kept from the last one,
  /// and marks seen only up to what this read brought.
  late final Future<void> _reading = ref
      .read(notificationsProvider.notifier)
      .refreshQuietly();

  @override
  void initState() {
    super.initState();
    _reading.ignore();
  }

  void _markSeen() {
    if (_seen) return;
    _seen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _reading;
      if (mounted) ref.read(notificationsProvider.notifier).markSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notificationFeedProvider);
    final data = feed.hasValue && !feed.hasError ? feed.value : null;
    final failed = data == null && feed.hasError && !feed.isLoading;
    if (data != null) _markSeen();
    if (Layout.isTablet(context)) return TabletNotifications(feed: feed);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: IqColors.bg,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Notifications',
                  onBack: () => goBack(context),
                ),
                Expanded(
                  child: LoadingGate(
                    loading: data == null && !failed,
                    skeleton: const _Skeleton(),
                    child: failed
                        ? _Failed(
                            onRetry: () => ref
                                .read(notificationsProvider.notifier)
                                .retry(),
                          )
                        : data == null
                        ? const SizedBox.shrink()
                        : data.isEmpty
                        ? const _Empty()
                        : _Feed(feed: data),
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

class _Feed extends ConsumerStatefulWidget {
  const _Feed({required this.feed});

  final NotificationFeed feed;

  @override
  ConsumerState<_Feed> createState() => _FeedState();
}

class _FeedState extends ConsumerState<_Feed> {
  late final bool _arrive = !ref.read(notificationsArrivedProvider);

  @override
  void initState() {
    super.initState();
    if (_arrive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(notificationsArrivedProvider.notifier).arrived();
      });
    }
  }

  Future<void> _open(NotificationItem item) async {
    final feed = ref.read(notificationsProvider.notifier);
    final link = item.link;
    if (link == null) {
      await feed.markRead(item.note.id);
      return;
    }
    if (link.tab) {
      feed.markRead(item.note.id);
      context.go(link.location);
      return;
    }
    await context.open(link.location);
    if (!mounted) return;
    whenUncovered(context, () => feed.markRead(item.note.id).ignore());
  }

  @override
  Widget build(BuildContext context) {
    var slot = 0;
    Widget title(String text) => StaggerItem(
      index: slot++,
      child: IqSectionTitle(title: text, showCount: false, showLink: false),
    );
    Widget group(List<NotificationItem> items) {
      final index = slot++;
      return StaggerItem(
        index: index,
        child: RowGroup(
          outlined: true,
          children: [
            for (final (i, item) in items.indexed)
              MergeSemantics(
                child: IqNotification(
                  key: ValueKey(item.note.id),
                  kind: item.kind,
                  headline: item.title,
                  detail: item.detail,
                  resultDetail: item.detail,
                  payoutDetail: item.detail,
                  when: item.when,
                  unread: item.note.unread,
                  divider: i < items.length - 1,
                  highlightDelay: _arrive && index < Stagger.moving
                      ? IqDurations.stagger * index + IqDurations.chain
                      : Duration.zero,
                  onTap: () => _open(item),
                ),
              ),
          ],
        ),
      );
    }

    final feed = widget.feed;
    return Stagger(
      play: _arrive,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          IqSpace.s4,
          0,
          IqSpace.s4,
          IqSpace.s4,
        ),
        children: [
          if (feed.today.isNotEmpty) ...[
            title('Today'),
            const SizedBox(height: IqSpace.s3),
            group(feed.today),
          ],
          if (feed.today.isNotEmpty && feed.earlier.isNotEmpty)
            const SizedBox(height: IqSpace.s6 + IqSpace.s3),
          if (feed.earlier.isNotEmpty) ...[
            title('Earlier'),
            const SizedBox(height: IqSpace.s3),
            group(feed.earlier),
          ],
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(height: IqSpace.s3),
          const IqSkeleton(kind: IqSkeletonKind.row),
        ],
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
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
    );
  }
}

/// 39:180: the Caller figure, "Nothing yet", its line and Browse briefs.
/// The figure rises in and the words appear after it (MOTION-SPEC §5.29).
class _Empty extends ConsumerWidget {
  const _Empty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IqEmptyFill(
      child: IqEmptyState(
        figure: IqFigures.caller,
        title: 'Nothing yet',
        body: 'Deadlines, results and payouts land here.',
        action: 'Browse briefs',
        onAction: () => browseForYou(context, ref),
      ),
    );
  }
}
