import '../drafts_data.dart';

/// A cached API answer: the decoded [json], the ETag it came with and when
/// it was fetched.
class CacheEntry {
  const CacheEntry({required this.json, required this.fetchedAt, this.etag});

  final Object? json;
  final String? etag;
  final DateTime fetchedAt;
}

enum OutboxStatus { pending, sending, failed, done }

/// The longest the outbox waits before sending an item again, unless the
/// API's Retry-After asks for longer.
const outboxLongestWait = Duration(minutes: 15);

/// A file sent with an outbox item. The store keeps where it is, not the
/// file itself.
class OutboxFile {
  const OutboxFile({
    required this.localPath,
    required this.bytes,
    required this.mime,
  });

  final String localPath;
  final int bytes;
  final String mime;
}

/// A write kept on the phone until the API takes it.
class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.userId,
    required this.kind,
    required this.payload,
    required this.status,
    required this.attempts,
    required this.nextAttemptAt,
    required this.createdAt,
    required this.updatedAt,
    this.coalesceKey,
    this.dependsOn,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.retryAfter,
    this.failingSince,
    this.serverRef,
    this.files = const [],
  });

  /// A UUID made on the phone, sent as the request's Idempotency-Key.
  final String id;
  final String userId;

  /// Names the handler that sends it.
  final String kind;

  /// Writes sharing a key fold into one item while it is unsent, and go out
  /// in order.
  final String? coalesceKey;
  final Map<String, dynamic> payload;

  /// The item that has to be done before this one goes.
  final String? dependsOn;
  final OutboxStatus status;

  /// Sends started so far.
  final int attempts;
  final DateTime nextAttemptAt;
  final String? lastErrorCode;
  final String? lastErrorMessage;

  /// The API's Retry-After that set [nextAttemptAt], if it gave one.
  final Duration? retryAfter;

  /// When the failures that keep the item waiting began, for giving up.
  final DateTime? failingSince;

  /// The id the API gave what it created, once done.
  final String? serverRef;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OutboxFile> files;

  /// When the item may go, seen at [now]: its next attempt, or now when that
  /// lies further ahead than any wait set for it, as after the phone's clock
  /// was set back.
  DateTime dueAt(DateTime now) {
    final after = retryAfter;
    final longest = after != null && after > outboxLongestWait
        ? after
        : outboxLongestWait;
    return nextAttemptAt.isAfter(now.add(longest)) ? now : nextAttemptAt;
  }

  @override
  String toString() => 'OutboxItem($kind $id ${status.name})';
}

/// Folds a newer payload into the pending one it coalesces with.
typedef OutboxMerge = Map<String, Object?> Function(
  Map<String, dynamic> older,
  Map<String, dynamic> newer,
);

/// What the app keeps on the phone for each person: cached API answers,
/// drafts, and the outbox of writes waiting to be sent. Every row carries
/// the person's id. Times come back in local time, to the microsecond they
/// went in.
abstract class LocalStore {
  Future<CacheEntry?> readCache(String userId, String key);

  /// Keeps [json] (anything `jsonEncode` takes) as fetched now.
  Future<void> writeCache(
    String userId,
    String key,
    Object? json, {
    String? etag,
  });

  /// Every cached answer of [userId], or the ones whose key starts with
  /// [keyPrefix].
  Future<void> deleteCache(String userId, {String? keyPrefix});

  /// Newest edit first.
  Future<List<Draft>> drafts(String userId);

  /// One draft per brief: saving replaces the brief's draft, and an empty
  /// draft removes it, as the demo repository does.
  Future<void> saveDraft(String userId, Draft draft);

  Future<void> deleteDrafts(String userId, Iterable<String> briefIds);

  /// Queues a write, due now. When [userId]'s newest unsent item with the
  /// same [coalesceKey] has never been sent, the write folds into it
  /// instead: the payload becomes [merge] of the two (the new payload alone
  /// without [merge]), the kind becomes [kind], [files] replace the old ones
  /// when there are any, and the item keeps its id and place in the queue.
  /// A write is queued after that item instead when the item has been sent
  /// (the API may already hold its Idempotency-Key) or names a different
  /// [dependsOn]. Answers the item as stored.
  Future<OutboxItem> enqueue(
    String userId, {
    required String kind,
    required Map<String, Object?> payload,
    String? coalesceKey,
    OutboxMerge? merge,
    String? dependsOn,
    List<OutboxFile> files = const [],
  });

  /// [userId]'s pending items that may go at [now] (see
  /// [OutboxItem.dueAt]), oldest first.
  Future<List<OutboxItem>> dueOutbox(String userId, DateTime now);

  /// [userId]'s items not done yet (pending, sending and failed), oldest
  /// first.
  Future<List<OutboxItem>> outbox(String userId);

  Future<OutboxItem?> outboxItem(String id);

  /// Claims a pending item for sending and counts the attempt. Answers the
  /// item as it goes out, or null when it is no longer pending.
  Future<OutboxItem?> markSending(String id);

  Future<void> markDone(String id, {String? serverRef});

  /// Back to pending until [at]. [retryAfter] is the API's wait that set
  /// [at]; [failingSince] keeps the item's give-up clock, and null stops it.
  Future<void> markRetry(
    String id, {
    required DateTime at,
    String? code,
    String? message,
    Duration? retryAfter,
    DateTime? failingSince,
  });

  Future<void> markFailed(String id, {required String code, String? message});

  /// Puts items a killed app left sending back to pending. Answers how many.
  Future<int> resetSending();

  /// Stops the give-up clock of [userId]'s unsent items, as when the queue
  /// pauses.
  Future<void> resetFailingSince(String userId);

  /// Drops done items last changed before [before], keeping the ones an
  /// unsent item depends on. Answers how many went.
  Future<int> pruneDone(DateTime before);

  Future<void> deleteOutbox(String userId);

  /// Removes everything kept for [userId]: cache, drafts and outbox.
  Future<void> wipeUser(String userId);

  Future<void> close();
}
