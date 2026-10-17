import 'dart:math';

import '../api_client.dart';
import '../models.dart';
import '../notifications_data.dart';
import '../notifications_service.dart';
import 'live_account.dart';

/// A `GET /notifications` row as the app's notification (contract 7):
/// `payout_confirmed` is a win reporting its ledger credit, the withdrawal
/// types report their withdrawal, and every other type keeps the API's
/// words. A row without an id or a time is dropped.
AppNotification? notificationFromJson(Map<String, dynamic> json) {
  final id = apiText(json['id']);
  final at = apiTime(json['createdAt']);
  if (id == null || at == null) return null;
  final type = apiText(json['type']) ?? '';
  final refs = _map(json['refs']);
  final brief = _brief(_map(json['brief']));
  final withdrawal = _withdrawal(_map(json['withdrawal']), at);
  final event = switch (type) {
    'payout_confirmed' => NotificationEvent.won,
    'withdrawal_requested' => NotificationEvent.withdrawalRequested,
    'payout_completed' => NotificationEvent.paidOut,
    'payout_failed' => NotificationEvent.payoutFailed,
    'review_ready' => NotificationEvent.resultsReady,
    'deadline_extended' => NotificationEvent.deadlineExtended,
    _ => NotificationEvent.other,
  };
  return AppNotification(
    id: id,
    event: event,
    at: at,
    briefId: brief?.id ?? apiText(refs['challengeId']),
    entryId: switch (event) {
      NotificationEvent.won => apiText(refs['ledgerId']),
      NotificationEvent.withdrawalRequested ||
      NotificationEvent.paidOut ||
      NotificationEvent.payoutFailed =>
        withdrawal?.id ?? apiText(refs['withdrawalId']),
      _ => null,
    },
    unread: json['readAt'] == null,
    facts: NotificationFacts(
      type: type,
      title: apiText(json['title']) ?? '',
      body: apiText(json['body']) ?? '',
      amountKobo: apiInt(json['amountKobo']),
      submissionId: apiText(refs['submissionId']),
      brief: brief,
      withdrawal: withdrawal,
    ),
  );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

NotificationBrief? _brief(Map<String, dynamic> json) {
  final id = apiText(json['id']);
  if (id == null) return null;
  return NotificationBrief(
    id: id,
    title: apiText(json['title']),
    businessName: apiText(json['businessName']),
  );
}

/// The row's time [at] stands in for the withdrawal's own, which the feed
/// does not embed. An unknown status reads as pending.
Withdrawal? _withdrawal(Map<String, dynamic> json, DateTime at) {
  final id = apiText(json['id']);
  final amount = apiInt(json['amountKobo']);
  if (id == null || amount == null) return null;
  return Withdrawal(
    id: id,
    amountKobo: amount,
    status:
        WithdrawalStatus.values.asNameMap()[json['status']] ??
        WithdrawalStatus.pending,
    createdAt: at,
    reference: apiText(json['reference']),
    bankName: apiText(json['bankName']),
    accountNumber: apiText(json['accountLast4']),
  );
}

List<Map<String, dynamic>> _items(Map<String, dynamic> page) => [
  if (page['items'] case final List<Object?> items)
    for (final item in items)
      if (item is Map) item.cast<String, dynamic>(),
];

List<String> _ids(Map<String, dynamic> mark) => [
  if (mark['ids'] case final List<Object?> ids)
    for (final id in ids)
      if (id is String) id,
];

/// [NotificationsService] on the API: the feed and the bell from
/// `GET /notifications`, kept for a read without a connection. Seen and
/// read marks queue in the outbox and count at once.
class LiveNotificationsService implements NotificationsService {
  LiveNotificationsService(this.link);

  final AccountLink link;

  /// The feed loads at most this many rows.
  static const cap = 100;

  /// The rows the bell reads, to count them against a seen mark still to
  /// go.
  static const bellRows = 20;

  /// The API takes at most this many ids in one read mark.
  static const readBatch = 100;

  DateTime? _newest;

  @override
  Future<List<AppNotification>> notifications() async {
    final feed = await _feed();
    final read = {
      for (final mark in await link.waiting(AccountWrite.read)) ..._ids(mark),
    };
    final rows = [
      for (final item in _items(feed))
        if (notificationFromJson(item) case final row?)
          read.contains(row.id) ? row.read() : row,
    ];
    for (final row in rows) {
      final newest = _newest;
      if (newest == null || row.at.isAfter(newest)) _newest = row.at;
    }
    return rows;
  }

  /// Every page up to [cap] rows, kept as one.
  Future<Map<String, dynamic>> _feed() async {
    final items = <Object?>[];
    int? unseen;
    String? cursor;
    try {
      do {
        final page = await _page(cap - items.length, cursor);
        unseen ??= apiInt(page['unseen']);
        final rows = _items(page);
        if (rows.isEmpty) break;
        items.addAll(rows);
        cursor = apiText(page['nextCursor']);
      } while (cursor != null && items.length < cap);
    } on ApiUnreachable {
      final kept = await link.kept(AccountKeys.notifications);
      if (kept != null) return kept;
      rethrow;
    }
    final feed = {'items': items.take(cap).toList(), 'unseen': unseen ?? 0};
    await link.keep(AccountKeys.notifications, feed);
    return feed;
  }

  Future<Map<String, dynamic>> _page(int limit, String? cursor) async {
    final query = Uri(queryParameters: {'limit': '$limit', 'cursor': ?cursor})
        .query;
    final res = await link.api.get('/notifications?$query');
    if (!res.ok) throw ApiRefused.of(res);
    return res.data;
  }

  /// Without an answer, what the feed kept says.
  @override
  Future<int> unseen() async {
    Map<String, dynamic> page;
    try {
      page = await _page(bellRows, null);
    } on ApiUnreachable {
      page = await link.kept(AccountKeys.notifications) ?? const {};
    } on ApiRefused {
      page = await link.kept(AccountKeys.notifications) ?? const {};
    }
    return _unseenAfterMarks(page);
  }

  /// The API's count, or fewer when a seen mark still to go covers rows it
  /// counts: the rows newer than both marks are the rows newer than the
  /// later one.
  Future<int> _unseenAfterMarks(Map<String, dynamic> page) async {
    final counted = apiInt(page['unseen']) ?? 0;
    DateTime? until;
    for (final mark in await link.waiting(AccountWrite.seen)) {
      final at = apiTime(mark['until']);
      if (at != null && (until == null || at.isAfter(until))) until = at;
    }
    if (until == null) return counted;
    final times = [for (final item in _items(page)) apiTime(item['createdAt'])];
    final newer = times.takeWhile((t) => t != null && t.isAfter(until!)).length;
    final whole = newer < times.length || apiText(page['nextCursor']) == null;
    return whole ? min(counted, newer) : counted;
  }

  @override
  Future<void> markSeen() async {
    final newest = _newest;
    if (newest == null) return;
    await _quietly(
      () => link.queue(AccountWrite.seen, {
        'until': newest.toUtc().toIso8601String(),
      }, merge: _later),
    );
  }

  @override
  Future<void> markRead(String id) => _quietly(
    () => link.queue(AccountWrite.read, {
      'ids': [id],
    }, merge: _allIds),
  );

  static Map<String, Object?> _later(
    Map<String, dynamic> older,
    Map<String, dynamic> newer,
  ) {
    final was = apiTime(older['until']);
    final now = apiTime(newer['until']);
    return was != null && (now == null || was.isAfter(now)) ? older : newer;
  }

  static Map<String, Object?> _allIds(
    Map<String, dynamic> older,
    Map<String, dynamic> newer,
  ) {
    final ids = {..._ids(older), ..._ids(newer)}.toList();
    return {'ids': ids.sublist(max(0, ids.length - readBatch))};
  }

  /// A mark sent straight to the API (no account id to queue it under) may
  /// not land; the feed and the bell then read as the API has them.
  static Future<void> _quietly(Future<void> Function() mark) async {
    try {
      await mark();
    } on ApiUnreachable {
      return;
    } on ApiRefused {
      return;
    }
  }
}
