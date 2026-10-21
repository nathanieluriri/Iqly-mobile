import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../theme/theme.dart';
import '../../ui/biz_segment.dart';
import '../../ui/button.dart';
import '../../ui/empty_state.dart';
import '../../ui/illustration.dart';
import '../../ui/notification.dart';
import '../../ui/switch.dart';
import '../shell/tablet_page.dart';
import '../shell/tablet_sheet.dart';
import 'notifications_state.dart';

enum _Filter { all, deadlines, results, payouts }

/// T13 · Notifications (Mobile App · tablet, 1848:54861). Landscape keeps
/// the 1024 split, the list beside the 412 detail; portrait gives the list
/// the full width and opens the detail as the 420 side sheet. The filters
/// stay on one line; the open row is the grey selected row. The page has
/// no rail item: it opens from the bell.
class TabletNotifications extends ConsumerStatefulWidget {
  const TabletNotifications({super.key, required this.feed});

  final AsyncValue<NotificationFeed> feed;

  @override
  ConsumerState<TabletNotifications> createState() =>
      _TabletNotificationsState();
}

class _TabletNotificationsState extends ConsumerState<TabletNotifications> {
  _Filter _filter = _Filter.all;
  bool _unreadOnly = false;
  String? _open;

  bool _keeps(NotificationItem item) =>
      (!_unreadOnly || item.note.unread) && _kind(item);

  bool _kind(NotificationItem item) => switch (_filter) {
    _Filter.all => true,
    _Filter.deadlines =>
      item.kind == IqNotificationKind.deadline ||
          item.kind == IqNotificationKind.spots,
    _Filter.results => item.kind == IqNotificationKind.result,
    _Filter.payouts => item.kind == IqNotificationKind.payout,
  };

  Future<void> _tap(NotificationItem item) async {
    final feed = ref.read(notificationsProvider.notifier);
    if (item.page != null) {
      feed.markRead(item.note.id).ignore();
      if (Layout.isExpanded(context)) {
        setState(() => _open = item.note.id);
      } else {
        setState(() => _open = item.note.id);
        await showTabletSideSheet<void>(
          context,
          width: 420,
          builder: (context) => NotificationDetailPanel(item: item),
        );
        if (mounted) setState(() => _open = null);
      }
      return;
    }
    final link = item.link;
    if (link == null) {
      await feed.markRead(item.note.id);
      return;
    }
    feed.markRead(item.note.id).ignore();
    link.tab ? context.go(link.location) : context.open(link.location);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.feed.value;
    final expanded = Layout.isExpanded(context);
    final filters = IqBizSegment.track(
      children: [
        for (final f in _Filter.values)
          IqBizSegment(
            label: switch (f) {
              _Filter.all => 'All',
              _Filter.deadlines => 'Deadlines',
              _Filter.results => 'Results',
              _Filter.payouts => 'Payouts',
            },
            state: f == _filter
                ? IqBizSegmentState.selected
                : IqBizSegmentState.standard,
            onTap: () => setState(() => _filter = f),
          ),
      ],
    );

    Widget body;
    if (data == null && widget.feed.hasError) {
      body = const IqEmptyState(
        figure: IqFigures.thinker,
        title: 'Couldn’t load. Check your connection.',
      );
    } else if (data == null) {
      body = const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: IqColors.primary),
        ),
      );
    } else if (data.isEmpty) {
      body = IqEmptyState(
        figure: IqFigures.caller,
        title: 'Nothing yet',
        body: 'Deadlines, results and payouts land here.',
        action: 'Browse briefs',
        onAction: () => context.go('/home'),
      );
    } else {
      final today = data.today.where(_keeps).toList();
      final earlier = data.earlier.where(_keeps).toList();
      // Landscape always shows a detail: the open row, else the first that
      // has one.
      final open = !expanded
          ? null
          : (_open == null ? null : data.item(_open!)) ??
                [...today, ...earlier].where((i) => i.page != null).firstOrNull;
      final selected = expanded ? open?.note.id : _open;
      Widget group(String title, List<NotificationItem> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: IqText.title.copyWith(color: IqColors.fg)),
          const SizedBox(height: IqSpace.s3),
          TabletCard(
            child: Column(
              children: [
                for (final (i, item) in items.indexed)
                  IqNotification(
                    key: ValueKey(item.note.id),
                    kind: item.kind,
                    headline: item.title,
                    detail: item.detail,
                    resultDetail: item.detail,
                    payoutDetail: item.detail,
                    when: item.when,
                    unread: item.note.unread,
                    divider: i < items.length - 1,
                    selected: item.note.id == selected,
                    onTap: () => _tap(item),
                  ),
              ],
            ),
          ),
        ],
      );
      final list = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (today.isNotEmpty) group('Today', today),
          if (today.isNotEmpty && earlier.isNotEmpty)
            const SizedBox(height: IqSpace.s6),
          if (earlier.isNotEmpty) group('Earlier', earlier),
          if (today.isEmpty && earlier.isEmpty)
            const IqEmptyState(figure: IqFigures.caller, title: 'Nothing yet'),
        ],
      );
      body = !expanded
          ? list
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: list),
                const SizedBox(width: IqSpace.s6),
                Container(
                  width: 412,
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: IqColors.line)),
                  ),
                  child: open == null || open.page == null
                      ? const SizedBox.shrink()
                      : NotificationDetailPanel(item: open, closable: false),
                ),
              ],
            );
    }

    return TabletPage(
      title: 'Notifications',
      children: [
        Row(
          children: [
            filters,
            const Spacer(),
            Text(
              'Unread only',
              style: IqWebText.bodySmall.copyWith(color: IqColors.fg2),
            ),
            const SizedBox(width: IqSpace.s2),
            IqSwitch(
              semanticLabel: 'Unread only',
              state: _unreadOnly ? IqSwitchState.on : IqSwitchState.off,
              onChanged: (state) =>
                  setState(() => _unreadOnly = state == IqSwitchState.on),
            ),
          ],
        ),
        body,
      ],
    );
  }
}

/// A notification opened: the row, read, one line about it and the one
/// button to the thing itself.
class NotificationDetailPanel extends StatelessWidget {
  const NotificationDetailPanel({
    super.key,
    required this.item,
    this.onClose,
    this.closable = true,
  });

  final NotificationItem item;
  final VoidCallback? onClose;
  final bool closable;

  @override
  Widget build(BuildContext context) {
    final page = item.page!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(IqSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Notification'.toUpperCase(),
                  style: IqText.mono.copyWith(color: IqColors.fg2),
                ),
              ),
              if (closable) TabletClose(onTap: onClose),
            ],
          ),
          const SizedBox(height: IqSpace.s3),
          IqNotification(
            kind: item.kind,
            headline: item.title,
            detail: item.detail,
            resultDetail: item.detail,
            payoutDetail: item.detail,
            when: item.when,
            unread: false,
            divider: false,
          ),
          const SizedBox(height: IqSpace.s5),
          Text(page.body, style: IqText.body.copyWith(color: IqColors.fg2)),
          const SizedBox(height: IqSpace.s5),
          IqButton(
            label: page.button,
            width: double.infinity,
            onTap: () {
              if (closable && onClose == null) {
                Navigator.of(context).maybePop();
              }
              page.link.tab
                  ? context.go(page.link.location)
                  : context.open(page.link.location);
            },
          ),
        ],
      ),
    );
  }
}
