import '../../core/session.dart';
import '../drafts_data.dart';
import 'local_store.dart';

/// [store] as one account's stretch ([scope]) uses it. Reads answer as the
/// store does; once the stretch has closed a cached answer or a draft goes
/// nowhere and nothing queues ([AccountChanged]), so nothing that lands
/// after a sign-out is kept on the phone for anyone. The outbox's own
/// bookkeeping passes straight through.
class ScopedLocalStore implements LocalStore {
  ScopedLocalStore(this.store, this.scope);

  final LocalStore store;
  final AccountScope scope;

  @override
  Future<CacheEntry?> readCache(String userId, String key) =>
      store.readCache(userId, key);

  @override
  Future<void> writeCache(
    String userId,
    String key,
    Object? json, {
    String? etag,
  }) async {
    if (scope.open) await store.writeCache(userId, key, json, etag: etag);
  }

  @override
  Future<void> deleteCache(String userId, {String? keyPrefix}) =>
      store.deleteCache(userId, keyPrefix: keyPrefix);

  @override
  Future<List<Draft>> drafts(String userId) => store.drafts(userId);

  @override
  Future<void> saveDraft(String userId, Draft draft) async {
    if (scope.open) await store.saveDraft(userId, draft);
  }

  @override
  Future<void> deleteDrafts(String userId, Iterable<String> briefIds) async {
    if (scope.open) await store.deleteDrafts(userId, briefIds);
  }

  @override
  Future<OutboxItem> enqueue(
    String userId, {
    required String kind,
    required Map<String, Object?> payload,
    String? coalesceKey,
    OutboxMerge? merge,
    String? dependsOn,
    List<OutboxFile> files = const [],
  }) {
    if (!scope.open) throw const AccountChanged();
    return store.enqueue(
      userId,
      kind: kind,
      payload: payload,
      coalesceKey: coalesceKey,
      merge: merge,
      dependsOn: dependsOn,
      files: files,
    );
  }

  @override
  Future<List<OutboxItem>> dueOutbox(String userId, DateTime now) =>
      store.dueOutbox(userId, now);

  @override
  Future<List<OutboxItem>> outbox(String userId) => store.outbox(userId);

  @override
  Future<OutboxItem?> outboxItem(String id) => store.outboxItem(id);

  @override
  Future<OutboxItem?> markSending(String id) => store.markSending(id);

  @override
  Future<void> markDone(String id, {String? serverRef}) =>
      store.markDone(id, serverRef: serverRef);

  @override
  Future<void> markRetry(
    String id, {
    required DateTime at,
    String? code,
    String? message,
    Duration? retryAfter,
    int failures = 0,
    DateTime? failingSince,
  }) => store.markRetry(
    id,
    at: at,
    code: code,
    message: message,
    retryAfter: retryAfter,
    failures: failures,
    failingSince: failingSince,
  );

  @override
  Future<void> markFailed(String id, {required String code, String? message}) =>
      store.markFailed(id, code: code, message: message);

  @override
  Future<int> resetSending() => store.resetSending();

  @override
  Future<void> resetFailures(String userId) => store.resetFailures(userId);

  @override
  Future<void> resetBackoff(String userId) => store.resetBackoff(userId);

  @override
  Future<bool> requeue(String id) => store.requeue(id);

  @override
  Future<bool> discard(String id, {required String dependantsCode}) =>
      store.discard(id, dependantsCode: dependantsCode);

  @override
  Future<int> pruneDone(DateTime before) => store.pruneDone(before);

  @override
  Future<void> deleteOutbox(String userId) => store.deleteOutbox(userId);

  @override
  Future<void> wipeUser(String userId) => store.wipeUser(userId);

  @override
  Future<void> close() => store.close();
}
