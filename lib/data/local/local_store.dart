import 'dart:io';

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

/// The code a failed item takes in place of its own when the store holds a
/// newer item of the same person with its coalesce key, whether that item
/// was queued before the failure or after it. The newer write carries what
/// the person wants now, so the failed one can only be discarded.
const outboxSupersededCode = 'SUPERSEDED';

/// Removes a queued file from the phone once no outbox item needs it.
typedef DeleteFile = Future<void> Function(String path);

/// Deletes the file at [path] from disk.
Future<void> deleteQueuedFile(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    // Already gone, which is all that was asked.
  }
}

/// A file sent with an outbox item. The outbox owns it: the file is deleted
/// from disk once no item needs it (done, replaced by a fold, discarded or
/// wiped).
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
    this.failures = 0,
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

  /// The API's Retry-After that [nextAttemptAt] waits out, if it gave one.
  final Duration? retryAfter;

  /// Sends that failed in a row and will be tried again. A pause starts the
  /// count again.
  final int failures;

  /// When that run of failures began, for showing.
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
  /// same [coalesceKey] has never been sent and names the same [dependsOn]
  /// (none counts as a value), the write folds into it instead: the payload
  /// becomes [merge] of the two (the new payload alone without [merge]), the
  /// kind becomes [kind], [files] replace the old files entirely, and the
  /// item keeps its id and place in the queue. Otherwise the write is queued
  /// after that item: a sent item's Idempotency-Key may already be used.
  /// Either way, [userId]'s failed items with [coalesceKey] take the code
  /// [outboxSupersededCode] and keep their files. Answers the item as
  /// stored.
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

  /// Marks the item done. Its files leave the phone.
  Future<void> markDone(String id, {String? serverRef});

  /// Back to pending until [at]. [retryAfter] is the API's wait that set
  /// [at]; [failures] and [failingSince] are the item's run of failures, and
  /// leaving them out ends it.
  Future<void> markRetry(
    String id, {
    required DateTime at,
    String? code,
    String? message,
    Duration? retryAfter,
    int failures = 0,
    DateTime? failingSince,
  });

  /// Fails the item with [code] and [message], or with
  /// [outboxSupersededCode] in place of [code] when a newer item of the same
  /// person has its coalesce key.
  Future<void> markFailed(String id, {required String code, String? message});

  /// Puts items a killed app left sending back to pending. Answers how many.
  Future<int> resetSending();

  /// Ends the run of failures of [userId]'s unsent items, as when the queue
  /// pauses, and puts their pending items due now.
  Future<void> resetFailures(String userId);

  /// Puts [userId]'s pending items due now, keeping their run of failures,
  /// as when the phone is back online. Items waiting out a Retry-After keep
  /// their wait.
  Future<void> resetBackoff(String userId);

  /// Puts a failed item back to pending, due now, with its run of failures
  /// ended. Answers whether it was failed.
  Future<bool> requeue(String id);

  /// Removes a pending or failed item and its files. The items that depend
  /// on it and are not on their way or done fail with [dependantsCode] (see
  /// [markFailed]). Answers whether it went: an item on its way or done
  /// stays.
  Future<bool> discard(String id, {required String dependantsCode});

  /// Drops done items last changed before [before], keeping the ones an
  /// item not done yet depends on. Answers how many went.
  Future<int> pruneDone(DateTime before);

  /// Removes [userId]'s outbox and its files.
  Future<void> deleteOutbox(String userId);

  /// Removes everything kept for [userId]: cache, drafts, outbox and files.
  Future<void> wipeUser(String userId);

  Future<void> close();
}

/// A store that can count what one person's cached answers take up.
abstract interface class CacheBytes {
  /// The bytes [userId]'s cached answers take as kept.
  Future<int> cacheBytes(String userId);
}
