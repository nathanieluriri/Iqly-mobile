import 'models.dart';

/// What a notification tells. Exp/Notification leads with its number: the
/// time or spots left on a brief, the naira won or moved.
enum NotificationEvent {
  /// A brief is closing (Kind=Deadline).
  closing,

  /// A brief is running out of spots (Kind=Spots).
  spots,

  /// The ledger paid an award (Kind=Result).
  won,

  /// An activation or referral reward reached the wallet (Kind=Payout).
  rewardCredited,

  /// A withdrawal was asked for (Kind=Payout).
  withdrawalRequested,

  /// A withdrawal arrived (Kind=Payout).
  paidOut,

  /// A withdrawal failed or was reversed, so it is back in the balance
  /// (Kind=Payout).
  payoutFailed,
}

/// One row of the feed as the API would send it: what happened, the brief
/// and the ledger award or withdrawal it reports, when, and whether it has
/// been opened. The feed is a design proposal (Exp/Notification); the app
/// words each row from the records it points at, so the figures foot.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.event,
    required this.at,
    this.briefId,
    this.entryId,
    this.unread = false,
  });

  final String id;
  final NotificationEvent event;
  final DateTime at;

  /// The brief it is about (closing, spots, won).
  final String? briefId;

  /// The ledger award (won) or the withdrawal (payouts) it reports.
  final String? entryId;
  final bool unread;

  AppNotification read() => AppNotification(
    id: id,
    event: event,
    at: at,
    briefId: briefId,
    entryId: entryId,
  );
}

/// The B6 feed (39:24) on the demo dataset, newest first. The first payout
/// is the Kudi Box activation reward, ledger row l6 (₦1,500.00 two hours
/// ago); the deadlines point at briefs c5 (Sunline, closing in 6 hours) and
/// c4 (Kudi Box, tomorrow); the result at ledger award l3 (₦12,500.00 two
/// days ago, paid for submission s2 on brief c3); the payouts at withdrawals
/// w2 (₦40,000.00 paid out ten days ago) and w1 (₦5,000.00 failed eleven
/// days ago), all in DemoData. When the two reminders went out (1h and 5h
/// before [now]) and which rows are unread (today's three,
/// DemoData.unreadNotifications) are the frame's.
List<AppNotification> demoNotifications({
  required List<LedgerEntry> ledger,
  required List<Withdrawal> withdrawals,
  required DateTime now,
}) {
  final awardAt = {for (final l in ledger) l.id: l.createdAt};
  final withdrawalAt = {for (final w in withdrawals) w.id: w.createdAt};
  return [
    if (awardAt['l6'] case final at?)
      AppNotification(
        id: 'n1',
        event: NotificationEvent.rewardCredited,
        entryId: 'l6',
        at: at,
        unread: true,
      ),
    AppNotification(
      id: 'n2',
      event: NotificationEvent.closing,
      briefId: 'c5',
      at: now.subtract(const Duration(hours: 1)),
      unread: true,
    ),
    AppNotification(
      id: 'n3',
      event: NotificationEvent.closing,
      briefId: 'c4',
      at: now.subtract(const Duration(hours: 5)),
      unread: true,
    ),
    if (awardAt['l3'] case final at?)
      AppNotification(
        id: 'n4',
        event: NotificationEvent.won,
        briefId: 'c3',
        entryId: 'l3',
        at: at,
      ),
    if (withdrawalAt['w2'] case final at?)
      AppNotification(
        id: 'n5',
        event: NotificationEvent.paidOut,
        entryId: 'w2',
        at: at,
      ),
    if (withdrawalAt['w1'] case final at?)
      AppNotification(
        id: 'n6',
        event: NotificationEvent.payoutFailed,
        entryId: 'w1',
        at: at,
      ),
  ]..sort((a, b) => b.at.compareTo(a.at));
}
