import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/notification.dart';
import '../more/more_widgets.dart';
import 'notifications_state.dart';

/// B6 · Notification, the sub page a payout (498:24308), result
/// (498:24590) or deadline (498:24830) row opens first: the row, read, one
/// line about it and one button to the thing itself (designer answer, 5
/// Oct). The button goes to the existing payout, result, brief or wallet
/// route; Back returns to the feed.
class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notificationsProvider.notifier).markRead(widget.id).ignore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notificationFeedProvider).value;
    final item = feed?.item(widget.id);
    final page = item?.page;
    return SubPage(
      title: 'Notification',
      body: item == null || page == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
              children: [
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
                Text(
                  page.body,
                  style: IqText.body.copyWith(color: IqColors.fg2),
                ),
                const SizedBox(height: IqSpace.s5),
                IqButton(
                  label: page.button,
                  width: double.infinity,
                  onTap: () => page.link.tab
                      ? context.go(page.link.location)
                      : context.push(page.link.location),
                ),
              ],
            ),
    );
  }
}
