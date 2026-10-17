import 'dart:async';

import 'package:iqly_mobile/data/drafts_data.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';

/// A server that keeps contract 1's idempotency rule: the same
/// Idempotency-Key from the same person answers the stored row with 200
/// instead of applying the body again.
class IdempotentServer {
  final resources = <String, Object?>{};
  final applied = <String>[];
  final requests = <String>[];
  final _byKey = <String, String>{};

  /// Sets the resource [item] names to its value, unless its key was seen,
  /// and answers as a handler would.
  OutboxResult post(OutboxItem item) {
    requests.add(item.id);
    final key = '${item.userId}/${item.id}';
    final seen = _byKey[key];
    if (seen != null) return outboxResultFor(status: 200, serverRef: seen);
    final id = 'r_${_byKey.length}';
    _byKey[key] = id;
    final resource = '${item.userId}/${item.payload['resource']}';
    resources[resource] = item.payload['value'];
    applied.add('$resource=${item.payload['value']}');
    return outboxResultFor(status: 201, serverRef: id);
  }
}

/// Forwards to [inner]. A test can hold [dueOutbox] until it completes
/// [dueGate], or make the next [resetSending] throw [failNextReset].
class GatedStore implements LocalStore {
  GatedStore(this.inner);

  final LocalStore inner;
  Completer<void>? dueGate;
  Object? failNextReset;

  @override
  Future<List<OutboxItem>> dueOutbox(String userId, DateTime now) async {
    await dueGate?.future;
    return inner.dueOutbox(userId, now);
  }

  @override
  Future<int> resetSending() async {
    final error = failNextReset;
    failNextReset = null;
    if (error != null) throw error;
    return inner.resetSending();
  }

  @override
  Future<CacheEntry?> readCache(String userId, String key) =>
      inner.readCache(userId, key);

  @override
  Future<void> writeCache(
    String userId,
    String key,
    Object? json, {
    String? etag,
  }) => inner.writeCache(userId, key, json, etag: etag);

  @override
  Future<void> deleteCache(String userId, {String? keyPrefix}) =>
      inner.deleteCache(userId, keyPrefix: keyPrefix);

  @override
  Future<List<Draft>> drafts(String userId) => inner.drafts(userId);

  @override
  Future<void> saveDraft(String userId, Draft draft) =>
      inner.saveDraft(userId, draft);

  @override
  Future<void> deleteDrafts(String userId, Iterable<String> briefIds) =>
      inner.deleteDrafts(userId, briefIds);

  @override
  Future<OutboxItem> enqueue(
    String userId, {
    required String kind,
    required Map<String, Object?> payload,
    String? coalesceKey,
    OutboxMerge? merge,
    String? dependsOn,
    List<OutboxFile> files = const [],
  }) => inner.enqueue(
    userId,
    kind: kind,
    payload: payload,
    coalesceKey: coalesceKey,
    merge: merge,
    dependsOn: dependsOn,
    files: files,
  );

  @override
  Future<List<OutboxItem>> outbox(String userId) => inner.outbox(userId);

  @override
  Future<OutboxItem?> outboxItem(String id) => inner.outboxItem(id);

  @override
  Future<OutboxItem?> markSending(String id) => inner.markSending(id);

  @override
  Future<void> markDone(String id, {String? serverRef}) =>
      inner.markDone(id, serverRef: serverRef);

  @override
  Future<void> markRetry(
    String id, {
    required DateTime at,
    String? code,
    String? message,
    Duration? retryAfter,
    DateTime? failingSince,
  }) => inner.markRetry(
    id,
    at: at,
    code: code,
    message: message,
    retryAfter: retryAfter,
    failingSince: failingSince,
  );

  @override
  Future<void> markFailed(String id, {required String code, String? message}) =>
      inner.markFailed(id, code: code, message: message);

  @override
  Future<void> resetFailingSince(String userId) =>
      inner.resetFailingSince(userId);

  @override
  Future<int> pruneDone(DateTime before) => inner.pruneDone(before);

  @override
  Future<void> deleteOutbox(String userId) => inner.deleteOutbox(userId);

  @override
  Future<void> wipeUser(String userId) => inner.wipeUser(userId);

  @override
  Future<void> close() => inner.close();
}
