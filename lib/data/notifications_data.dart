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

  /// The business published its results (Kind=Result), in the API's words.
  resultsReady,

  /// A brief has more time (Kind=Deadline), in the API's words.
  deadlineExtended,

  /// A row the app has no design for, in the API's words.
  other,
}

/// The brief a live feed row embeds; no business name while the brief
/// keeps it private.
class NotificationBrief {
  const NotificationBrief({required this.id, this.title, this.businessName});

  final String id;
  final String? title;
  final String? businessName;
}

/// What a live feed row says itself (contract 7): the API's type and words
/// and the records it embeds, so the app can word the row without loading
/// them.
class NotificationFacts {
  const NotificationFacts({
    required this.type,
    required this.title,
    required this.body,
    this.amountKobo,
    this.submissionId,
    this.ticketId,
    this.brief,
    this.withdrawal,
    this.pollId,
    this.activationId,
  });

  final String type;
  final String title;
  final String body;
  final int? amountKobo;
  final String? submissionId;

  /// The help thread support answered (`support` rows).
  final String? ticketId;
  final NotificationBrief? brief;

  /// The poll or activation the row is about (contract 11).
  final String? pollId;
  final String? activationId;

  /// As embedded: the amount, status, bank, last 4 digits and reference.
  final Withdrawal? withdrawal;
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
    this.facts,
  });

  final String id;
  final NotificationEvent event;
  final DateTime at;

  /// The brief it is about (closing, spots, won).
  final String? briefId;

  /// The ledger award (won) or the withdrawal (payouts) it reports.
  final String? entryId;
  final bool unread;

  /// What the API's feed row says itself; null for a demo row.
  final NotificationFacts? facts;

  AppNotification read() => AppNotification(
    id: id,
    event: event,
    at: at,
    briefId: briefId,
    entryId: entryId,
    facts: facts,
  );
}

/// The B6 feed (39:24) on the demo dataset, newest first. The first payout
/// is the Kudi Box activation reward, ledger row l6 (₦1,500.00 three days
/// ago, as the Wallet frames date it; 39:24 shows it two hours ago); the
/// deadlines point at briefs c5 (Sunline, closing in 6 hours) and
/// c4 (Kudi Box, tomorrow); the result at ledger award l3 (₦12,500.00 two
/// days ago, paid for submission s2 on brief c3); the payouts at withdrawals
/// w2 (₦40,000.00 paid out ten days ago) and w1 (₦5,000.00 failed eleven
/// days ago), all in DemoData. When the two reminders went out (1h and 5h
/// before [now]) and which rows are unread (the two reminders and the
/// reward, DemoData.unreadNotifications) are the frame's.
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
