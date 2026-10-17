import 'dart:convert';
import 'dart:math';

import '../drafts_data.dart';
import 'local_store.dart';

/// The rows both stores keep, as the SQLite tables hold them: times in
/// microseconds since the epoch and JSON as text. The in-memory store keeps
/// the same rows so it answers exactly what the database does.
abstract final class LocalRows {
  static const cache = 'cache';
  static const drafts = 'drafts';
  static const outbox = 'outbox';
  static const outboxFiles = 'outbox_files';

  static int time(DateTime at) => at.microsecondsSinceEpoch;

  static DateTime timeOf(Object? value) =>
      DateTime.fromMicrosecondsSinceEpoch(value! as int);

  static DateTime? timeOrNull(Object? value) =>
      value == null ? null : timeOf(value);

  static Map<String, Object?> cacheRow(
    String userId,
    String key,
    Object? json,
    String? etag,
    DateTime fetchedAt,
  ) => {
    'user_id': userId,
    'cache_key': key,
    'body': jsonEncode(json),
    'etag': etag,
    'fetched_at': time(fetchedAt),
  };

  static CacheEntry cacheEntry(Map<String, Object?> row) => CacheEntry(
    json: jsonDecode(row['body']! as String),
    etag: row['etag'] as String?,
    fetchedAt: timeOf(row['fetched_at']),
  );

  static Map<String, Object?> draftRow(String userId, Draft draft) => {
    'user_id': userId,
    'brief_id': draft.briefId,
    'title': draft.title,
    'answer': draft.answer,
    'answers': jsonEncode(draft.answers),
    'step': draft.step,
    'edited_at': time(draft.editedAt),
  };

  static Draft draft(Map<String, Object?> row) {
    final answers = payloadOf(row['answers']! as String);
    return Draft(
      briefId: row['brief_id']! as String,
      title: row['title']! as String,
      answer: row['answer']! as String,
      answers: {
        for (final MapEntry(:key, :value) in answers.entries)
          key: [for (final option in value as List) option as String],
      },
      step: row['step']! as int,
      editedAt: timeOf(row['edited_at']),
    );
  }

  /// Newest edit first, then by brief, as the drafts query orders them.
  static int byEdit(Map<String, Object?> a, Map<String, Object?> b) {
    final edited = (b['edited_at']! as int).compareTo(a['edited_at']! as int);
    return edited != 0
        ? edited
        : (a['brief_id']! as String).compareTo(b['brief_id']! as String);
  }

  static Map<String, Object?> outboxRow({
    required String id,
    required String userId,
    required String kind,
    required String? coalesceKey,
    required String payload,
    required String? dependsOn,
    required DateTime now,
  }) => {
    'id': id,
    'user_id': userId,
    'kind': kind,
    'coalesce_key': coalesceKey,
    'payload': payload,
    'depends_on': dependsOn,
    'status': OutboxStatus.pending.name,
    'attempts': 0,
    'next_attempt_at': time(now),
    'last_error_code': null,
    'last_error_message': null,
    'retry_after': null,
    'failing_since': null,
    'server_ref': null,
    'created_at': time(now),
    'updated_at': time(now),
  };

  static OutboxItem outboxItem(
    Map<String, Object?> row,
    Iterable<Map<String, Object?>> files,
  ) => OutboxItem(
    id: row['id']! as String,
    userId: row['user_id']! as String,
    kind: row['kind']! as String,
    coalesceKey: row['coalesce_key'] as String?,
    payload: payloadOf(row['payload']! as String),
    dependsOn: row['depends_on'] as String?,
    status: OutboxStatus.values.byName(row['status']! as String),
    attempts: row['attempts']! as int,
    nextAttemptAt: timeOf(row['next_attempt_at']),
    lastErrorCode: row['last_error_code'] as String?,
    lastErrorMessage: row['last_error_message'] as String?,
    retryAfter: switch (row['retry_after']) {
      final int micros => Duration(microseconds: micros),
      _ => null,
    },
    failingSince: timeOrNull(row['failing_since']),
    serverRef: row['server_ref'] as String?,
    createdAt: timeOf(row['created_at']),
    updatedAt: timeOf(row['updated_at']),
    files: [for (final file in files) fileOf(file)],
  );

  static Map<String, dynamic> payloadOf(String text) =>
      jsonDecode(text) as Map<String, dynamic>;

  /// Whether a write naming [dependsOn] may fold into [row], the newest
  /// unsent item with its key: only while that item has never been sent.
  static bool folds(Map<String, Object?> row, String? dependsOn) =>
      row['status'] == OutboxStatus.pending.name &&
      row['attempts'] == 0 &&
      (dependsOn == null || dependsOn == row['depends_on']);

  /// The values [LocalStore.markRetry] writes.
  static Map<String, Object?> retryRow({
    required DateTime at,
    required String? code,
    required String? message,
    required Duration? retryAfter,
    required DateTime? failingSince,
  }) => {
    'status': OutboxStatus.pending.name,
    'next_attempt_at': time(at),
    'last_error_code': code,
    'last_error_message': message,
    'retry_after': retryAfter?.inMicroseconds,
    'failing_since': failingSince == null ? null : time(failingSince),
  };

  /// The payload text of a pending item after a newer write folds into it.
  static String coalesce(String older, String newer, OutboxMerge? merge) =>
      merge == null
      ? newer
      : jsonEncode(merge(payloadOf(older), payloadOf(newer)));

  static Map<String, Object?> fileRow(String outboxId, OutboxFile file) => {
    'outbox_id': outboxId,
    'local_path': file.localPath,
    'bytes': file.bytes,
    'mime': file.mime,
  };

  static OutboxFile fileOf(Map<String, Object?> row) => OutboxFile(
    localPath: row['local_path']! as String,
    bytes: row['bytes']! as int,
    mime: row['mime']! as String,
  );

  static final _random = Random.secure();

  /// A random (version 4) UUID.
  static String newId() {
    final bytes = [for (var i = 0; i < 16; i++) _random.nextInt(256)];
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = [
      for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
