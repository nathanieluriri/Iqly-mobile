import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/brief_labels.dart';
import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../core/relative_time.dart';
import '../../data/models.dart';
import '../../data/notifications_data.dart';
import '../../data/notifications_service.dart';
import '../../data/repository.dart';
import '../../router.dart';
import '../../ui/notification.dart';
import '../submissions/submissions_routes.dart';
import '../wallet/wallet_routes.dart';
import '../wallet/wallet_state.dart';
import 'notifications_routes.dart';

/// The feed and what has been read. No automatic retry: the failed state
/// offers "Try again".
class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() =>
      ref.watch(notificationsServiceProvider).notifications();

  void retry() => ref.invalidateSelf();

  /// The feed is on screen, so the bell on every tab clears.
  Future<void> markSeen() async {
    await ref.read(notificationsServiceProvider).markSeen();
    ref.invalidate(unreadNotificationsProvider);
  }

  /// The person opened [id].
  Future<void> markRead(String id) async {
    final data = state.value;
    if (data != null) {
      state = AsyncData([for (final n in data) n.id == id ? n.read() : n]);
    }
    await ref.read(notificationsServiceProvider).markRead(id);
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
      retry: (_, _) => null,
    );

/// Whether the feed has arrived once this session; later visits show it in
/// place (MOTION-SPEC §7.5).
class NotificationsArrivedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void arrived() => state = true;
}

final notificationsArrivedProvider =
    NotifierProvider<NotificationsArrivedNotifier, bool>(
      NotificationsArrivedNotifier.new,
    );

/// Where a row or a sub page's button leads. A [tab] gives way to that dock
/// tab instead of pushing over the feed.
class NotificationLink {
  const NotificationLink.push(this.location) : tab = false;
  const NotificationLink.tab(this.location) : tab = true;

  final String location;
  final bool tab;
}

/// The Notification sub page (498:24308 payout, 498:24590 result, 498:24830
/// deadline): the row again, one line about it and one button to the thing
/// itself.
class NotificationDetail {
  const NotificationDetail({
    required this.body,
    required this.button,
    required this.link,
  });

  final String body;
  final String button;
  final NotificationLink link;
}

/// A feed row worded from the records it points at.
class NotificationItem {
  const NotificationItem({
    required this.note,
    required this.kind,
    required this.title,
    required this.detail,
    required this.when,
    this.link,
    this.page,
  });

  final AppNotification note;
  final IqNotificationKind kind;
  final String title;
  final String detail;

  /// "2h", "11d": the mono time on the row.
  final String when;

  /// Where the row leads: its sub page when it has one.
  final NotificationLink? link;

  /// Payout, result and deadline rows open a sub page first (designer
  /// answer, 5 Oct).
  final NotificationDetail? page;
}

/// The feed split as the frame shows it: today, then earlier.
class NotificationFeed {
  const NotificationFeed({required this.today, required this.earlier});

  final List<NotificationItem> today;
  final List<NotificationItem> earlier;

  bool get isEmpty => today.isEmpty && earlier.isEmpty;

  NotificationItem? item(String id) =>
      [...today, ...earlier].where((i) => i.note.id == id).firstOrNull;
}

/// Each row worded from the live records: brief deadlines and spots, the
/// ledger awards and rewards and the withdrawals the wallet holds now, so
/// every figure foots to the wallet and Discover.
final notificationFeedProvider = FutureProvider.autoDispose<NotificationFeed>(
  retry: (_, _) => null,
  (ref) async {
    final notes = await ref.watch(notificationsProvider.future);
    final (briefs, wallet) = await (
      ref.watch(repositoryProvider).briefs(),
      ref.watch(walletProvider.future),
    ).wait;
    final now = ref.watch(clockProvider)();
    final items = [
      for (final note in notes)
        ?wordNotification(
          note,
          briefs: {for (final b in briefs) b.id: b},
          awards: {for (final l in wallet.ledger) l.id: l},
          withdrawals: {for (final w in wallet.withdrawals) w.id: w},
          now: now,
        ),
    ];
    bool today(NotificationItem item) => DateUtils.isSameDay(item.note.at, now);
    return NotificationFeed(
      today: [
        for (final item in items)
          if (today(item)) item,
      ],
      earlier: [
        for (final item in items)
          if (!today(item)) item,
      ],
    );
  },
);

/// "3:06 pm".
String _clock(DateTime at) => DateFormat('h:mm a').format(at).toLowerCase();

/// The words of one row and its sub page, or null when what it points at is
/// gone.
NotificationItem? wordNotification(
  AppNotification note, {
  required Map<String, Brief> briefs,
  required Map<String, LedgerEntry> awards,
  required Map<String, Withdrawal> withdrawals,
  required DateTime now,
}) {
  final when = timeAgoShort(note.at, now).replaceFirst(' ago', '');
  NotificationItem item(
    IqNotificationKind kind,
    String title,
    String detail, {
    NotificationDetail? page,
    NotificationLink? link,
  }) => NotificationItem(
    note: note,
    kind: kind,
    title: title,
    detail: detail,
    when: when,
    page: page,
    link: page != null
        ? NotificationLink.push(notificationPath(note.id))
        : link,
  );

  switch (note.event) {
    case NotificationEvent.closing:
      final brief = briefs[note.briefId];
      final deadline = brief?.deadline;
      if (brief == null) return null;
      final business = brief.businessName ?? 'Private business';
      final tomorrow =
          deadline != null &&
          DateUtils.isSameDay(deadline, DateUtils.addDaysToDate(note.at, 1));
      final day = deadline == null
          ? ''
          : DateUtils.isSameDay(deadline, now)
          ? 'today'
          : DateUtils.isSameDay(deadline, DateUtils.addDaysToDate(now, 1))
          ? 'tomorrow'
          : 'on ${DateFormat('d MMMM').format(deadline)}';
      return item(
        IqNotificationKind.deadline,
        tomorrow
            ? '$business closes tomorrow'
            : closesIn(timeLeft(deadline, note.at), closed: !brief.isLive),
        tomorrow ? brief.title : [business, brief.title].join(' · '),
        page: NotificationDetail(
          body: deadline == null
              ? '“${brief.title}” is open.'
              : '“${brief.title}” closes $day at ${_clock(deadline)}.',
          button: 'See the brief',
          link: NotificationLink.push(Routes.brief(brief.id)),
        ),
      );
    case NotificationEvent.spots:
      final brief = briefs[note.briefId];
      if (brief == null) return null;
      return item(
        IqNotificationKind.spots,
        spotsLeftLabel(brief),
        [?brief.businessName, brief.title].join(' · '),
        link: NotificationLink.push(Routes.brief(brief.id)),
      );
    case NotificationEvent.won:
      final award = awards[note.entryId];
      if (award == null) return null;
      final submission = award.submissionId;
      final brief = briefs[note.briefId];
      final amount = naira(award.amountKobo);
      final who = brief?.businessName ?? 'A business kept private';
      return item(
        IqNotificationKind.result,
        'You won $amount',
        brief?.title ?? '',
        page: submission == null
            ? null
            : NotificationDetail(
                body:
                    '$who picked your answer to “${brief?.title ?? ''}”. '
                    '$amount is in your wallet now.',
                button: 'See the result',
                link: NotificationLink.push(resultPath(submission)),
              ),
      );
    case NotificationEvent.rewardCredited:
      final reward = awards[note.entryId];
      if (reward == null) return null;
      final amount = naira(reward.amountKobo);
      final from = reward.rewardFrom ?? '';
      final referral = reward.reward == LedgerReward.referral;
      return item(
        IqNotificationKind.payout,
        '$amount added to your wallet',
        '$from · ${referral ? 'referral' : 'activation'} reward',
        page: NotificationDetail(
          body: referral
              ? '$amount for inviting $from is in your wallet now.'
              : '$amount for the $from activation is in your wallet now.',
          button: 'Open wallet',
          link: const NotificationLink.tab(Routes.wallet),
        ),
      );
    case NotificationEvent.withdrawalRequested ||
        NotificationEvent.paidOut ||
        NotificationEvent.payoutFailed:
      final withdrawal = withdrawals[note.entryId];
      if (withdrawal == null) return null;
      final amount = naira(withdrawal.amountKobo);
      final to = withdrawal.destination ?? 'your bank';
      final open = NotificationLink.push(withdrawalPath(withdrawal.id));
      return switch (note.event) {
        NotificationEvent.withdrawalRequested => item(
          IqNotificationKind.payout,
          '$amount requested',
          '$to · ${withdrawal.statusWord}',
          page: NotificationDetail(
            body: '$amount is on its way to $to.',
            button: 'Track it',
            link: open,
          ),
        ),
        NotificationEvent.paidOut => () {
          final arrived = withdrawal.completedAt ?? withdrawal.createdAt;
          final reference = withdrawal.reference;
          return item(
            IqNotificationKind.payout,
            '$amount paid out',
            'Sent to $to · ${withdrawal.statusWord}',
            page: NotificationDetail(
              body:
                  '$amount arrived at $to on '
                  '${DateFormat('d MMMM').format(arrived)} at '
                  '${_clock(arrived)}. '
                  '${reference == null ? '' : 'Reference $reference. '}'
                  'It can take your bank a few minutes to show it.',
              button: 'Open wallet',
              link: open,
            ),
          );
        }(),
        _ => () {
          final reversed = withdrawal.status == WithdrawalStatus.reversed;
          final reason = withdrawal.failureReason;
          return item(
            IqNotificationKind.payout,
            reversed
                ? '$amount is back in your wallet'
                : '$amount never left your wallet',
            'Withdrawal to $to ${withdrawal.statusWord}',
            page: NotificationDetail(
              body:
                  '$amount to $to ${withdrawal.statusWord}.'
                  '${reason == null ? '' : ' $reason'} '
                  '${reversed ? 'It is back in your wallet.' : 'Nothing left your wallet.'}',
              button: 'See what happened',
              link: open,
            ),
          );
        }(),
      };
  }
}
