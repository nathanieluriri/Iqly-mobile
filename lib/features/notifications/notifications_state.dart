import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Where a row leads (the B6 prototype). A [tab] gives way to that dock tab
/// instead of pushing over the feed.
class NotificationLink {
  const NotificationLink.push(this.location) : tab = false;
  const NotificationLink.tab(this.location) : tab = true;

  final String location;
  final bool tab;
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
  });

  final AppNotification note;
  final IqNotificationKind kind;
  final String title;
  final String detail;

  /// "2h", "11d": the mono time on the row.
  final String when;
  final NotificationLink? link;
}

/// The feed split as the frame shows it: today, then earlier.
class NotificationFeed {
  const NotificationFeed({required this.today, required this.earlier});

  final List<NotificationItem> today;
  final List<NotificationItem> earlier;

  bool get isEmpty => today.isEmpty && earlier.isEmpty;
}

/// Each row worded from the live records: brief deadlines and spots, the
/// ledger award and the withdrawals the wallet holds now, so every figure
/// foots to the wallet and Discover.
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

/// The words of one row, or null when what it points at is gone.
NotificationItem? wordNotification(
  AppNotification note, {
  required Map<String, Brief> briefs,
  required Map<String, LedgerEntry> awards,
  required Map<String, Withdrawal> withdrawals,
  required DateTime now,
}) {
  final when = timeAgoShort(note.at, now).replaceFirst(' ago', '');
  switch (note.event) {
    case NotificationEvent.closing || NotificationEvent.spots:
      final brief = briefs[note.briefId];
      if (brief == null) return null;
      final closing = note.event == NotificationEvent.closing;
      return NotificationItem(
        note: note,
        kind: closing ? IqNotificationKind.deadline : IqNotificationKind.spots,
        title: closing
            ? closesIn(timeLeft(brief.deadline, now), closed: !brief.isLive)
            : spotsLeftLabel(brief),
        detail: [?brief.businessName, brief.title].join(' · '),
        when: when,
        link: NotificationLink.push(Routes.brief(brief.id)),
      );
    case NotificationEvent.won:
      final award = awards[note.entryId];
      if (award == null) return null;
      final submission = award.submissionId;
      return NotificationItem(
        note: note,
        kind: IqNotificationKind.result,
        title: 'You won ${naira(award.amountKobo)}',
        detail: briefs[note.briefId]?.title ?? '',
        when: when,
        link: submission == null
            ? null
            : NotificationLink.push(submissionPath(submission)),
      );
    case NotificationEvent.withdrawalRequested ||
        NotificationEvent.paidOut ||
        NotificationEvent.payoutFailed:
      final withdrawal = withdrawals[note.entryId];
      if (withdrawal == null) return null;
      final amount = naira(withdrawal.amountKobo);
      final to = withdrawal.destination;
      final (title, detail) = switch (note.event) {
        NotificationEvent.withdrawalRequested => (
          '$amount requested',
          [?to, withdrawal.statusWord].join(' · '),
        ),
        NotificationEvent.paidOut => (
          '$amount paid out',
          [if (to != null) 'Sent to $to', withdrawal.statusWord].join(' · '),
        ),
        _ => (
          '$amount payout ${withdrawal.statusWord}',
          [?to, 'back in your balance'].join(' · '),
        ),
      };
      return NotificationItem(
        note: note,
        kind: IqNotificationKind.payout,
        title: title,
        detail: detail,
        when: when,
        link: note.event == NotificationEvent.paidOut
            ? const NotificationLink.tab(Routes.wallet)
            : NotificationLink.push(withdrawalPath(withdrawal.id)),
      );
  }
}
