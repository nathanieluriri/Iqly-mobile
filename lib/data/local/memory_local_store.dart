import 'dart:convert';

import '../drafts_data.dart';
import 'local_rows.dart';
import 'local_store.dart';

/// The local store kept in memory, for Windows and tests. It keeps the same
/// rows as the SQLite store and answers the same way, but forgets them when
/// the app closes.
class MemoryLocalStore implements LocalStore {
  MemoryLocalStore({DateTime Function()? clock, DeleteFile? deleteFile})
    : _clock = clock ?? DateTime.now,
      _deleteFile = deleteFile ?? deleteQueuedFile;

  final DateTime Function() _clock;
  final DeleteFile _deleteFile;
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
    final Map<String, Object?> row;
    var replaced = const <String>[];
    if (older != null && LocalRows.folds(older, dependsOn)) {
      row = older
        ..addAll({
          'kind': kind,
          'payload': LocalRows.coalesce(
            older['payload']! as String,
            body,
            merge,
          ),
          'updated_at': LocalRows.time(now),
        });
      replaced = _dropFiles({row['id']});
    } else {
      row = LocalRows.outboxRow(
        id: LocalRows.newId(),
        userId: userId,
        kind: kind,
        coalesceKey: coalesceKey,
        payload: body,
        dependsOn: dependsOn,
        now: now,
      );
      _outbox.add(row);
    }
    if (coalesceKey != null) {
      _updateAll(
        (other) =>
            other['user_id'] == userId &&
            other['coalesce_key'] == coalesceKey &&
            other['status'] == OutboxStatus.failed.name,
        {'last_error_code': outboxSupersededCode},
      );
    }
    final id = row['id']! as String;
    _files.addAll([for (final file in files) LocalRows.fileRow(id, file)]);
    final item = _item(row);
    await _deleteUnused(replaced);
    return item;
  }

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

  /// Drops the file rows of the items [ids] and answers their paths.
  List<String> _dropFiles(Set<Object?> ids) {
    final paths = <String>{
      for (final file in _files)
        if (ids.contains(file['outbox_id'])) file['local_path']! as String,
    };
    _files.removeWhere((file) => ids.contains(file['outbox_id']));
    return paths.toList();
  }

  /// Deletes the files at [paths] that no queued item needs any more.
  Future<void> _deleteUnused(List<String> paths) async {
    final unused = [
      for (final path in paths)
        if (!_files.any((file) => file['local_path'] == path)) path,
    ];
    for (final path in unused) {
      await _deleteFile(path);
    }
  }

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
  Future<void> markDone(String id, {String? serverRef}) async {
    _update(id, {'status': OutboxStatus.done.name, 'server_ref': serverRef});
    await _deleteUnused(_dropFiles({id}));
  }

  @override
  Future<void> markRetry(
    String id, {
    required DateTime at,
    String? code,
    String? message,
    Duration? retryAfter,
    int failures = 0,
    DateTime? failingSince,
  }) async => _update(
    id,
    LocalRows.retryRow(
      at: at,
      code: code,
      message: message,
      retryAfter: retryAfter,
      failures: failures,
      failingSince: failingSince,
    ),
  );

  @override
  Future<void> markFailed(
    String id, {
    required String code,
    String? message,
  }) async {
    final row = _row(id);
    if (row != null) _fail(row, code, message);
  }

  void _fail(Map<String, Object?> row, String code, String? message) {
    row.addAll({
      'status': OutboxStatus.failed.name,
      'last_error_code': _overtaken(row) ? outboxSupersededCode : code,
      'last_error_message': message,
      'updated_at': LocalRows.time(_clock()),
    });
  }

  /// Whether a newer item of [row]'s person has its coalesce key.
  bool _overtaken(Map<String, Object?> row) {
    final key = row['coalesce_key'];
    if (key == null) return false;
    return _outbox
        .skip(_outbox.indexOf(row) + 1)
        .any(
          (newer) =>
              newer['user_id'] == row['user_id'] &&
              newer['coalesce_key'] == key,
        );
  }

  @override
  Future<int> resetSending() async => _updateAll(
    (row) => row['status'] == OutboxStatus.sending.name,
    {'status': OutboxStatus.pending.name},
  );

  @override
  Future<void> resetFailures(String userId) async {
    _updateAll((row) => row['user_id'] == userId && _unsent(row), {
      'failures': 0,
      'failing_since': null,
    });
    await resetBackoff(userId);
  }

  @override
  Future<void> resetBackoff(String userId) async {
    _updateAll(
      (row) =>
          row['user_id'] == userId &&
          row['status'] == OutboxStatus.pending.name,
      LocalRows.dueRow(_clock()),
    );
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
  Future<bool> requeue(String id) async {
    final row = _row(id);
    if (row == null || row['status'] != OutboxStatus.failed.name) return false;
    final now = _clock();
    row.addAll({
      ...LocalRows.requeueRow(now),
      'updated_at': LocalRows.time(now),
    });
    return true;
  }

  @override
  Future<bool> discard(String id, {required String dependantsCode}) async {
    final row = _row(id);
    final status = row?['status'];
    if (row == null ||
        status == OutboxStatus.sending.name ||
        status == OutboxStatus.done.name) {
      return false;
    }
    for (final other in _outbox) {
      if (other['depends_on'] == id &&
          (other['status'] == OutboxStatus.pending.name ||
              other['status'] == OutboxStatus.failed.name)) {
        _fail(other, dependantsCode, null);
      }
    }
    await _removeOutbox((other) => identical(other, row));
    return true;
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

  Future<int> _removeOutbox(
    bool Function(Map<String, Object?> row) test,
  ) async {
    final gone = {
      for (final row in _outbox)
        if (test(row)) row['id'],
    };
    _outbox.removeWhere((row) => gone.contains(row['id']));
    await _deleteUnused(_dropFiles(gone));
    return gone.length;
  }

  @override
  Future<void> deleteOutbox(String userId) async {
    await _removeOutbox((row) => row['user_id'] == userId);
  }

  @override
  Future<void> wipeUser(String userId) async {
    _cache.removeWhere((id, _) => id.$1 == userId);
    _drafts.removeWhere((id, _) => id.$1 == userId);
    await _removeOutbox((row) => row['user_id'] == userId);
  }

  @override
  Future<void> close() async {}
}
