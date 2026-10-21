import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../core/tablet_layout.dart';
import '../../router.dart';
import '../../ui/biz_crumb.dart';
import '../outcomes/outcomes_state.dart' show resultProvider;
import '../../data/help_service.dart' show supportChannelsProvider;
import '../../theme/theme.dart';
import '../help/chat_inbox_screen.dart';
import '../help/chat_state.dart' show helpInboxTicketsProvider;
import '../help/chat_thread_screen.dart';
import '../help/help_state.dart' show conversationsProvider;
import '../help/help_thread_screen.dart';
import '../help/support_screen.dart';
import '../outcomes/leaderboard_screen.dart';

/// Two of the app's pages side by side, each laid out at its own width.
class _Panes extends StatelessWidget {
  const _Panes({
    required this.leftWidth,
    required this.left,
    required this.right,
  });

  final double leftWidth;
  final Widget left;
  final Widget right;

  static Widget _sized(Widget page) => LayoutBuilder(
    builder: (context, box) => MediaQuery(
      data: MediaQuery.of(context).copyWith(size: box.biggest),
      child: page,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: leftWidth, child: _sized(left)),
        const SizedBox(width: 1, child: ColoredBox(color: IqColors.line)),
        Expanded(child: _sized(right)),
      ],
    );
  }
}

/// T14 · Support (Mobile App · tablet, 1849:55649): two panes in both
/// layouts, the inbox (280 in portrait, 320 in landscape) beside the open
/// thread; the support inbox alone opens its latest thread there. The
/// inbox and the thread are the app's own, unchanged.
class TabletSupportSplit extends ConsumerWidget {
  const TabletSupportSplit({super.key, required this.thread, this.page});

  /// The thread's id, or null for the inbox itself.
  final String? thread;

  /// The thread's page as its route built it.
  final Widget? page;

  static String? threadOf(String location) {
    final match = RegExp(r'^/help/([^/]+)$').firstMatch(location);
    return match?[1];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(supportChannelsProvider);
    final latest = channels
        ? ref.watch(helpInboxTicketsProvider)?.firstOrNull?.id
        : ref.watch(conversationsProvider).value?.firstOrNull?.id;
    final id = thread ?? latest;
    final right =
        page ??
        (id == null
            ? null
            : channels
            ? ChatThreadScreen(key: ValueKey(id), id: id)
            : HelpThreadScreen(key: ValueKey(id), id: id));
    final inbox = channels ? const ChatInboxScreen() : const SupportScreen();
    if (right == null) return inbox;
    return _Panes(
      leftWidth: Layout.isExpanded(context) ? 320 : 280,
      // The inbox is the rail's root here: no back bar beside the thread.
      left: TabletInSplit(
        child: Padding(
          padding: const EdgeInsets.only(top: IqSpace.s4),
          child: inbox,
        ),
      ),
      right: right,
    );
  }
}

/// T8 · Result (Mobile App · tablet, 1856:63429), landscape: the result
/// column (420) beside the leaderboard for that brief.
class TabletResultSplit extends ConsumerWidget {
  const TabletResultSplit({super.key, required this.id, required this.page});

  final String id;
  final Widget page;

  static String? resultOf(String location) =>
      RegExp(r'^/submissions/([^/]+)/result$').firstMatch(location)?[1];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Layout.isExpanded(context)) return page;
    final title = ref.watch(resultProvider(id)).value?.item.submission.title;
    return Material(
      color: IqColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // T12 (1856:65015): one trail over both panes.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s6,
              IqSpace.s3,
              IqSpace.s6,
              0,
            ),
            child: Row(
              children: [
                Flexible(
                  flex: 2,
                  child: IqBizCrumb(
                    label: 'My submissions',
                    onTap: () => context.go(Routes.submissions),
                  ),
                ),
                const SizedBox(width: IqSpace.s1),
                if (title != null) ...[
                  Flexible(flex: 2, child: IqBizCrumb(label: title)),
                  const SizedBox(width: IqSpace.s1),
                ],
                const Flexible(
                  flex: 3,
                  child: IqBizCrumb(
                    label: 'Your result',
                    state: IqBizCrumbState.current,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _Panes(
              leftWidth: 460,
              left: TabletInSplit(boardBeside: true, child: page),
              right: TabletInSplit(child: LeaderboardScreen(id: id)),
            ),
          ),
        ],
      ),
    );
  }
}
