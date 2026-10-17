import 'dart:convert';

import '../drafts_data.dart';
import 'local_rows.dart';
import 'local_store.dart';

/// The local store kept in memory, for Windows and tests. It keeps the same
/// rows as the SQLite store and answers the same way, but forgets them when
/// the app closes.
class MemoryLocalStore implements LocalStore {
  MemoryLocalStore({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _cache = <(String, String), Map<String, Object?>>{};
  final _drafts = <(String, String), Map<String, Object?>>{};
  final _outbox = <Map<String, Object?>>[];
  final _files = <Map<String, Object?>>[];

  @override
  Future<CacheEntry?> readCache(String userId, String key) async {
    final row = _cache[(userId, key)];
    return row == null ? null : LocalRows.cacheEntry(row);
  }

  @override
  Future<void> writeCache(
    String userId,
    String key,
    Object? json, {
    String? etag,
  }) async {
    _cache[(userId, key)] = LocalRows.cacheRow(
      userId,
      key,
      json,
      etag,
      _clock(),
    );
  }

  @override
  Future<void> deleteCache(String userId, {String? keyPrefix}) async {
    _cache.removeWhere(
      (id, _) =>
          id.$1 == userId && (keyPrefix == null || id.$2.startsWith(keyPrefix)),
    );
  }

  @override
  Future<List<Draft>> drafts(String userId) async {
    final rows = [
      for (final row in _drafts.values)
        if (row['user_id'] == userId) row,
    ]..sort(LocalRows.byEdit);
    return [for (final row in rows) LocalRows.draft(row)];
  }

  @override
  Future<void> saveDraft(String userId, Draft draft) async {
    final id = (userId, draft.briefId);
    if (draft.isEmpty) {
      _drafts.remove(id);
    } else {
      _drafts[id] = LocalRows.draftRow(userId, draft);
    }
  }

  @override
  Future<void> deleteDrafts(String userId, Iterable<String> briefIds) async {
    for (final briefId in briefIds) {
      _drafts.remove((userId, briefId));
    }
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
  }) async {
    final body = jsonEncode(payload);
    final now = _clock();
    final older = coalesceKey == null
        ? null
        : _outbox
              .where(
                (row) =>
                    row['user_id'] == userId &&
                    row['coalesce_key'] == coalesceKey &&
                    _unsent(row),
              )
              .lastOrNull;
    if (older != null && LocalRows.folds(older, dependsOn)) {
      older.addAll({
        'kind': kind,
        'payload': LocalRows.coalesce(older['payload']! as String, body, merge),
        'updated_at': LocalRows.time(now),
      });
      if (files.isNotEmpty) _attach(older['id']! as String, files);
      return _item(older);
    }
    final row = LocalRows.outboxRow(
      id: LocalRows.newId(),
      userId: userId,
      kind: kind,
      coalesceKey: coalesceKey,
      payload: body,
      dependsOn: dependsOn,
      now: now,
    );
    _outbox.add(row);
    _attach(row['id']! as String, files);
    return _item(row);
  }

  void _attach(String id, List<OutboxFile> files) => _files
    ..removeWhere((file) => file['outbox_id'] == id)
    ..addAll([for (final file in files) LocalRows.fileRow(id, file)]);

  OutboxItem _item(Map<String, Object?> row) => LocalRows.outboxItem(row, [
    for (final file in _files)
      if (file['outbox_id'] == row['id']) file,
  ]);

  Map<String, Object?>? _row(String id) =>
      _outbox.where((row) => row['id'] == id).firstOrNull;

  static bool _unsent(Map<String, Object?> row) =>
      row['status'] == OutboxStatus.pending.name ||
      row['status'] == OutboxStatus.sending.name;

  void _update(String id, Map<String, Object?> values) =>
      _row(id)?.addAll({...values, 'updated_at': LocalRows.time(_clock())});

  @override
  Future<List<OutboxItem>> dueOutbox(String userId, DateTime now) async => [
    for (final row in _outbox)
      if (row['user_id'] == userId &&
          row['status'] == OutboxStatus.pending.name)
        _item(row),
  ].where((item) => !item.dueAt(now).isAfter(now)).toList();

  @override
  Future<List<OutboxItem>> outbox(String userId) async => [
    for (final row in _outbox)
      if (row['user_id'] == userId && row['status'] != OutboxStatus.done.name)
        _item(row),
  ];

  @override
  Future<OutboxItem?> outboxItem(String id) async {
    final row = _row(id);
    return row == null ? null : _item(row);
  }

  @override
  Future<OutboxItem?> markSending(String id) async {
    final row = _row(id);
    if (row == null || row['status'] != OutboxStatus.pending.name) return null;
    _update(id, {
      'status': OutboxStatus.sending.name,
      'attempts': (row['attempts']! as int) + 1,
    });
    return _item(row);
  }

  @override
  Future<void> markDone(String id, {String? serverRef}) async =>
      _update(id, {'status': OutboxStatus.done.name, 'server_ref': serverRef});

  @override
  Future<void> markRetry(
    String id, {
    required DateTime at,
    String? code,
    String? message,
    Duration? retryAfter,
    DateTime? failingSince,
  }) async => _update(
    id,
    LocalRows.retryRow(
      at: at,
      code: code,
      message: message,
      retryAfter: retryAfter,
      failingSince: failingSince,
    ),
  );

  @override
  Future<void> markFailed(
    String id, {
    required String code,
    String? message,
  }) async => _update(id, {
    'status': OutboxStatus.failed.name,
    'last_error_code': code,
    'last_error_message': message,
  });

  @override
  Future<int> resetSending() async => _updateAll(
    (row) => row['status'] == OutboxStatus.sending.name,
    {'status': OutboxStatus.pending.name},
  );

  @override
  Future<void> resetFailingSince(String userId) async {
    _updateAll((row) => row['user_id'] == userId && _unsent(row), {
      'failing_since': null,
    });
  }

  int _updateAll(
    bool Function(Map<String, Object?> row) test,
    Map<String, Object?> values,
  ) {
    final rows = _outbox.where(test).toList();
    final now = LocalRows.time(_clock());
    for (final row in rows) {
      row.addAll({...values, 'updated_at': now});
    }
    return rows.length;
  }

  @override
  Future<int> pruneDone(DateTime before) async {
    final needed = {
      for (final row in _outbox)
        if (row['status'] != OutboxStatus.done.name) row['depends_on'],
    };
    return _removeOutbox(
      (row) =>
          row['status'] == OutboxStatus.done.name &&
          (row['updated_at']! as int) < LocalRows.time(before) &&
          !needed.contains(row['id']),
    );
  }

  int _removeOutbox(bool Function(Map<String, Object?> row) test) {
    final gone = {
      for (final row in _outbox)
        if (test(row)) row['id'],
    };
    _outbox.removeWhere((row) => gone.contains(row['id']));
    _files.removeWhere((file) => gone.contains(file['outbox_id']));
    return gone.length;
  }

  @override
  Future<void> deleteOutbox(String userId) async {
    _removeOutbox((row) => row['user_id'] == userId);
  }

  @override
  Future<void> wipeUser(String userId) async {
    _cache.removeWhere((id, _) => id.$1 == userId);
    _drafts.removeWhere((id, _) => id.$1 == userId);
    _removeOutbox((row) => row['user_id'] == userId);
  }

  @override
  Future<void> close() async {}
}
