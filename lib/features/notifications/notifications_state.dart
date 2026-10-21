import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/brief_labels.dart';
import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../core/relative_time.dart';
import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/notifications_data.dart';
import '../../data/help_service.dart' show supportShownProvider;
import '../../data/notifications_service.dart';
import '../../data/referrals_service.dart' show referralsShownProvider;
import '../../data/repository.dart';
import '../../router.dart';
import '../../ui/notification.dart';
import '../activations/activations_routes.dart' show activationPath;
import '../activations/activations_state.dart';
import '../help/help_routes.dart' show helpThreadPath;
import '../help/chat_state.dart' show helpInboxProvider;
import '../help/help_state.dart';
import '../polls/polls_routes.dart' show quickPollsFor;
import '../polls/polls_state.dart';
import '../submissions/submissions_routes.dart';
import '../submissions/submissions_state.dart';
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

  /// Reads the feed again behind the rows shown (a push, a visit); a
  /// failure keeps them.
  Future<void> refreshQuietly() async {
    if (!state.hasValue) return;
    final scope = ref.read(accountScopeProvider);
    final List<AppNotification> rows;
    try {
      rows = await ref.read(notificationsServiceProvider).notifications();
    } on Object {
      return;
    }
    if (ref.mounted && scope.open) state = AsyncData(rows);
  }

  /// The feed is on screen, so the bell on every tab clears, while its
  /// account is still the one signed in.
  Future<void> markSeen() async {
    final scope = ref.read(accountScopeProvider);
    await ref.read(notificationsServiceProvider).markSeen();
    if (scope.open) ref.invalidate(unreadNotificationsProvider);
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

/// A push landed with iQLY open: the bell, the feed, My submissions, the
/// polls, the activations, the support badge and any open help thread read
/// again behind what they show, whichever of them this run has loaded.
void readAgainOnPush(Ref ref) {
  ref.invalidate(unreadNotificationsProvider);
  ref.invalidate(supportUnreadProvider);
  if (ref.exists(helpTicketsProvider)) {
    ref.read(helpTicketsProvider.notifier).refreshOpen();
  }
  if (ref.exists(helpInboxProvider) &&
      ref.read(helpInboxProvider).tickets != null) {
    ref.read(helpInboxProvider.notifier).refresh(quiet: true).ignore();
  }
  if (ref.exists(notificationsProvider)) {
    ref.read(notificationsProvider.notifier).refreshQuietly().ignore();
  }
  if (ref.exists(mySubmissionsProvider)) {
    ref.read(mySubmissionsProvider.notifier).refreshQuietly();
  }
  if (ref.exists(pollsProvider)) {
    ref.read(pollsProvider.notifier).refreshQuietly().ignore();
  }
  if (ref.exists(activationsProvider)) {
    ref.read(activationsProvider.notifier).refreshQuietly().ignore();
  }
}

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
/// every figure foots to the wallet and Discover. A row from the API brings
/// what it reports with it, so none waits for those records or goes without
/// them.
final notificationFeedProvider = FutureProvider.autoDispose<NotificationFeed>(
  retry: (_, _) => null,
  (ref) async {
    final notes = await ref.watch(notificationsProvider.future);
    var briefs = const <Brief>[];
    var ledger = const <LedgerEntry>[];
    var withdrawals = const <Withdrawal>[];
    if (notes.any((n) => n.facts == null)) {
      final (all, wallet) = await (
        ref.watch(repositoryProvider).briefs(),
        ref.watch(walletProvider.future),
      ).wait;
      briefs = all;
      ledger = wallet.ledger;
      withdrawals = wallet.withdrawals;
    }
    final now = ref.watch(clockProvider)();
    final support = ref.watch(supportShownProvider);
    final referrals = ref.watch(referralsShownProvider);
    final polls = ref.watch(pollsShownProvider);
    final activations = ref.watch(activationsShownProvider);
    final items = [
      for (final note in notes)
        ?wordNotification(
          note,
          briefs: {for (final b in briefs) b.id: b},
          awards: {for (final l in ledger) l.id: l},
          withdrawals: {for (final w in withdrawals) w.id: w},
          now: now,
          support: support,
          referrals: referrals,
          polls: polls,
          activations: activations,
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

/// The words of one row and its sub page, or null when what a demo row
/// points at is gone. A row from the API is worded from what it embeds;
/// the API's own title and body stand in where the app has no design or
/// the row lacks what the design needs. A support reply opens its thread,
/// a referral reward Referral history and a poll or activation row its poll
/// or activation, as their pushes do, only while the launch shows them
/// ([support], [referrals], [polls], [activations]).
NotificationItem? wordNotification(
  AppNotification note, {
  required Map<String, Brief> briefs,
  required Map<String, LedgerEntry> awards,
  required Map<String, Withdrawal> withdrawals,
  required DateTime now,
  bool support = true,
  bool referrals = true,
  bool polls = false,
  bool activations = false,
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

  final facts = note.facts;
  NotificationItem? said() => facts == null
      ? null
      : item(
          _kindOf(note),
          facts.title,
          facts.body,
          link: _linkOf(
            note,
            support: support,
            polls: polls,
            activations: activations,
          ),
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
      final brief = briefs[note.briefId];
      final amountKobo = facts == null ? award?.amountKobo : facts.amountKobo;
      if (amountKobo == null) return said();
      final submission = facts == null
          ? award?.submissionId
          : facts.submissionId;
      final title = facts == null ? brief?.title : facts.brief?.title;
      final business = facts == null
          ? brief?.businessName
          : facts.brief?.businessName;
      final amount = naira(amountKobo);
      final who = business ?? 'A business kept private';
      return item(
        IqNotificationKind.result,
        'You won $amount',
        title ?? '',
        page: submission == null
            ? null
            : NotificationDetail(
                body:
                    '$who picked your answer to “${title ?? ''}”. '
                    '$amount is in your wallet now.',
                button: 'See the result',
                link: NotificationLink.push(resultPath(submission)),
              ),
      );
    case NotificationEvent.rewardCredited when facts != null:
      return item(
        IqNotificationKind.payout,
        facts.title,
        facts.body,
        link: referrals
            ? const NotificationLink.push(Routes.referralHistory)
            : const NotificationLink.tab(Routes.wallet),
      );
    case NotificationEvent.rewardCredited:
      final reward = awards[note.entryId];
      if (reward == null) return null;
      final amount = naira(reward.amountKobo);
      final from = reward.rewardFrom ?? '';
      final referral = reward.source == RewardSource.referral;
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
      final withdrawal = facts == null
          ? withdrawals[note.entryId]
          : facts.withdrawal;
      if (withdrawal == null) return said();
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
    case NotificationEvent.resultsReady ||
        NotificationEvent.deadlineExtended ||
        NotificationEvent.other:
      return said();
  }
}

/// The mark a row in the API's words wears: its event's, and for a type the
/// app does not know, the wallet's when it is about money, else the clock's.
IqNotificationKind _kindOf(AppNotification note) => switch (note.event) {
  NotificationEvent.closing ||
  NotificationEvent.deadlineExtended => IqNotificationKind.deadline,
  NotificationEvent.spots => IqNotificationKind.spots,
  NotificationEvent.won ||
  NotificationEvent.resultsReady => IqNotificationKind.result,
  NotificationEvent.rewardCredited ||
  NotificationEvent.withdrawalRequested ||
  NotificationEvent.paidOut ||
  NotificationEvent.payoutFailed => IqNotificationKind.payout,
  NotificationEvent.other =>
    note.facts?.withdrawal != null || note.facts?.amountKobo != null
        ? IqNotificationKind.payout
        : IqNotificationKind.deadline,
};

/// Where a row in the API's words leads, as its push does: the help thread
/// support answered, the brief it is about, else the activation or the
/// poll's business, else the withdrawal, else nowhere but read.
NotificationLink? _linkOf(
  AppNotification note, {
  required bool support,
  required bool polls,
  required bool activations,
}) {
  final ticket = note.facts?.ticketId;
  if (ticket != null) {
    return support ? NotificationLink.push(helpThreadPath(ticket)) : null;
  }
  final brief = note.briefId;
  if (brief != null) return NotificationLink.push(Routes.brief(brief));
  final activation = note.facts?.activationId;
  if (activation != null) {
    return activations
        ? NotificationLink.push(activationPath(activation))
        : null;
  }
  final poll = note.facts?.pollId;
  if (poll != null) {
    return polls ? NotificationLink.push(quickPollsFor(poll)) : null;
  }
  final withdrawal =
      note.facts?.withdrawal?.id ??
      switch (note.event) {
        NotificationEvent.withdrawalRequested ||
        NotificationEvent.paidOut ||
        NotificationEvent.payoutFailed => note.entryId,
        _ => null,
      };
  return withdrawal == null
      ? null
      : NotificationLink.push(withdrawalPath(withdrawal));
}
