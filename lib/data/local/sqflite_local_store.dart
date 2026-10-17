import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../drafts_data.dart';
import 'local_rows.dart';
import 'local_store.dart';

/// The local store in the phone's own SQLite, through sqflite.
class SqfliteLocalStore implements LocalStore {
  SqfliteLocalStore._(this._db, this._clock);

  static const schemaVersion = 1;

  /// Opens the store, creating or upgrading its tables. A relative [path]
  /// lands in the app's databases directory. [factory] defaults to the
  /// sqflite plugin's; tests pass sqflite_common_ffi's.
  static Future<SqfliteLocalStore> open({
    String path = 'iqly_local.db',
    DatabaseFactory? factory,
    DateTime Function()? clock,
  }) async {
    final db = await (factory ?? databaseFactorySqflitePlugin).openDatabase(
      path,
      options: OpenDatabaseOptions(version: schemaVersion, onUpgrade: _upgrade),
    );
    return SqfliteLocalStore._(db, clock ?? DateTime.now);
  }

  // A fresh install runs every step. Steps must be safe to run twice: a
  // rolled back patch reopens the file at its older version, and the next
  // update runs the newer steps again.
  static const _steps = <Future<void> Function(Database db)>[_createV1];

  static Future<void> _upgrade(Database db, int from, int to) async {
    for (var version = from; version < to; version++) {
      await _steps[version](db);
    }
  }

  static Future<void> _createV1(Database db) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE IF NOT EXISTS ${LocalRows.cache} (
          user_id TEXT NOT NULL,
          cache_key TEXT NOT NULL,
          body TEXT NOT NULL,
          etag TEXT,
          fetched_at INTEGER NOT NULL,
          PRIMARY KEY (user_id, cache_key)
        )''')
      ..execute('''
        CREATE TABLE IF NOT EXISTS ${LocalRows.drafts} (
          user_id TEXT NOT NULL,
          brief_id TEXT NOT NULL,
          title TEXT NOT NULL,
          answer TEXT NOT NULL,
          answers TEXT NOT NULL,
          step INTEGER NOT NULL,
          edited_at INTEGER NOT NULL,
          PRIMARY KEY (user_id, brief_id)
        )''')
      ..execute('''
        CREATE TABLE IF NOT EXISTS ${LocalRows.outbox} (
          seq INTEGER PRIMARY KEY,
          id TEXT NOT NULL UNIQUE,
          user_id TEXT NOT NULL,
          kind TEXT NOT NULL,
          coalesce_key TEXT,
          payload TEXT NOT NULL,
          depends_on TEXT,
          status TEXT NOT NULL,
          attempts INTEGER NOT NULL,
          next_attempt_at INTEGER NOT NULL,
          last_error_code TEXT,
          last_error_message TEXT,
          retry_after INTEGER,
          failing_since INTEGER,
          server_ref TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )''')
      ..execute(
        'CREATE INDEX IF NOT EXISTS outbox_user_status '
        'ON ${LocalRows.outbox} (user_id, status)',
      )
      ..execute('''
        CREATE TABLE IF NOT EXISTS ${LocalRows.outboxFiles} (
          outbox_id TEXT NOT NULL,
          local_path TEXT NOT NULL,
          bytes INTEGER NOT NULL,
          mime TEXT NOT NULL
        )''')
      ..execute(
        'CREATE INDEX IF NOT EXISTS outbox_files_item '
        'ON ${LocalRows.outboxFiles} (outbox_id)',
      );
    await batch.commit(noResult: true);
  }

  final Database _db;
  final DateTime Function() _clock;

  static final _pending = OutboxStatus.pending.name;
  static final _sending = OutboxStatus.sending.name;
  static final _failed = OutboxStatus.failed.name;
  static final _done = OutboxStatus.done.name;

  @override
  Future<CacheEntry?> readCache(String userId, String key) async {
    final rows = await _db.query(
      LocalRows.cache,
      where: 'user_id = ? AND cache_key = ?',
      whereArgs: [userId, key],
    );
    return rows.isEmpty ? null : LocalRows.cacheEntry(rows.single);
  }

  @override
  Future<void> writeCache(
    String userId,
    String key,
    Object? json, {
    String? etag,
  }) async {
    await _db.insert(
      LocalRows.cache,
      LocalRows.cacheRow(userId, key, json, etag, _clock()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteCache(String userId, {String? keyPrefix}) async {
    await _db.delete(
      LocalRows.cache,
      where: keyPrefix == null
          ? 'user_id = ?'
          : 'user_id = ? AND substr(cache_key, 1, length(?)) = ?',
      whereArgs: [
        userId,
        if (keyPrefix != null) ...[keyPrefix, keyPrefix],
      ],
    );
  }

  @override
  Future<List<Draft>> drafts(String userId) async {
    final rows = await _db.query(
      LocalRows.drafts,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'edited_at DESC, brief_id',
    );
    return [for (final row in rows) LocalRows.draft(row)];
  }

  @override
  Future<void> saveDraft(String userId, Draft draft) async {
    if (draft.isEmpty) return deleteDrafts(userId, [draft.briefId]);
    await _db.insert(
      LocalRows.drafts,
      LocalRows.draftRow(userId, draft),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteDrafts(String userId, Iterable<String> briefIds) async {
    final batch = _db.batch();
    for (final briefId in briefIds.toSet()) {
      batch.delete(
        LocalRows.drafts,
        where: 'user_id = ? AND brief_id = ?',
        whereArgs: [userId, briefId],
      );
    }
    await batch.commit(noResult: true);
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
    return _db.transaction((txn) async {
      final now = _clock();
      if (coalesceKey != null) {
        final rows = await txn.query(
          LocalRows.outbox,
          where: 'user_id = ? AND coalesce_key = ? AND status IN (?, ?)',
          whereArgs: [userId, coalesceKey, _pending, _sending],
          orderBy: 'seq DESC',
          limit: 1,
        );
        final older = rows.firstOrNull;
        if (older != null && LocalRows.folds(older, dependsOn)) {
          final id = older['id']! as String;
          await txn.update(
            LocalRows.outbox,
            {
              'kind': kind,
              'payload': LocalRows.coalesce(
                older['payload']! as String,
                body,
                merge,
              ),
              'updated_at': LocalRows.time(now),
            },
            where: 'id = ?',
            whereArgs: [id],
          );
          if (files.isNotEmpty) await _attach(txn, id, files);
          return (await _items(txn, 'id = ?', [id])).single;
        }
      }
      final id = LocalRows.newId();
      await txn.insert(
        LocalRows.outbox,
        LocalRows.outboxRow(
          id: id,
          userId: userId,
          kind: kind,
          coalesceKey: coalesceKey,
          payload: body,
          dependsOn: dependsOn,
          now: now,
        ),
      );
      await _attach(txn, id, files);
      return (await _items(txn, 'id = ?', [id])).single;
    });
  }

  static Future<void> _attach(
    Transaction txn,
    String id,
    List<OutboxFile> files,
  ) async {
    await txn.delete(
      LocalRows.outboxFiles,
      where: 'outbox_id = ?',
      whereArgs: [id],
    );
    for (final file in files) {
      await txn.insert(LocalRows.outboxFiles, LocalRows.fileRow(id, file));
    }
  }

  /// The outbox rows matching [where] (on outbox columns), oldest first,
  /// with their files.
  static Future<List<OutboxItem>> _items(
    DatabaseExecutor db,
    String where,
    List<Object?> args,
  ) async {
    final rows = await db.query(
      LocalRows.outbox,
      where: where,
      whereArgs: args,
      orderBy: 'seq',
    );
    if (rows.isEmpty) return const [];
    final files = <Object?, List<Map<String, Object?>>>{};
    for (final file in await db.rawQuery(
      'SELECT f.* FROM ${LocalRows.outboxFiles} f '
      'JOIN ${LocalRows.outbox} ON ${LocalRows.outbox}.id = f.outbox_id '
      'WHERE $where ORDER BY f.rowid',
      args,
    )) {
      (files[file['outbox_id']] ??= []).add(file);
    }
    return [
      for (final row in rows)
        LocalRows.outboxItem(row, files[row['id']] ?? const []),
    ];
  }

  Future<int> _update(String id, Map<String, Object?> values) => _db.update(
    LocalRows.outbox,
    {...values, 'updated_at': LocalRows.time(_clock())},
    where: 'id = ?',
    whereArgs: [id],
  );

  @override
  Future<List<OutboxItem>> dueOutbox(String userId, DateTime now) => _items(
    _db,
    'user_id = ? AND status = ? AND (next_attempt_at <= ? OR '
    'next_attempt_at > ? + max(?, coalesce(retry_after, 0)))',
    [
      userId,
      _pending,
      LocalRows.time(now),
      LocalRows.time(now),
      outboxLongestWait.inMicroseconds,
    ],
  );

  @override
  Future<List<OutboxItem>> outbox(String userId) =>
      _items(_db, 'user_id = ? AND status != ?', [userId, _done]);

  @override
  Future<OutboxItem?> outboxItem(String id) async =>
      (await _items(_db, 'id = ?', [id])).firstOrNull;

  @override
  Future<OutboxItem?> markSending(String id) => _db.transaction((txn) async {
    final claimed = await txn.rawUpdate(
      'UPDATE ${LocalRows.outbox} '
      'SET status = ?, attempts = attempts + 1, updated_at = ? '
      'WHERE id = ? AND status = ?',
      [_sending, LocalRows.time(_clock()), id, _pending],
    );
    return claimed == 0 ? null : (await _items(txn, 'id = ?', [id])).single;
  });

  @override
  Future<void> markDone(String id, {String? serverRef}) async {
    await _update(id, {'status': _done, 'server_ref': serverRef});
  }

  @override
  Future<void> markRetry(
    String id, {
    required DateTime at,
    String? code,
    String? message,
    Duration? retryAfter,
    DateTime? failingSince,
  }) async {
    await _update(
      id,
      LocalRows.retryRow(
        at: at,
        code: code,
        message: message,
        retryAfter: retryAfter,
        failingSince: failingSince,
      ),
    );
  }

  @override
  Future<void> markFailed(
    String id, {
    required String code,
    String? message,
  }) async {
    await _update(id, {
      'status': _failed,
      'last_error_code': code,
      'last_error_message': message,
    });
  }

  @override
  Future<int> resetSending() => _db.update(
    LocalRows.outbox,
    {'status': _pending, 'updated_at': LocalRows.time(_clock())},
    where: 'status = ?',
    whereArgs: [_sending],
  );

  @override
  Future<void> resetFailingSince(String userId) async {
    await _db.update(
      LocalRows.outbox,
      {'failing_since': null, 'updated_at': LocalRows.time(_clock())},
      where: 'user_id = ? AND status IN (?, ?)',
      whereArgs: [userId, _pending, _sending],
    );
  }

  @override
  Future<int> pruneDone(DateTime before) => _db.transaction((txn) async {
    final stale =
        'status = ? AND updated_at < ? AND id NOT IN '
        '(SELECT depends_on FROM ${LocalRows.outbox} '
        'WHERE depends_on IS NOT NULL AND status != ?)';
    final args = [_done, LocalRows.time(before), _done];
    await txn.rawDelete(
      'DELETE FROM ${LocalRows.outboxFiles} WHERE outbox_id IN '
      '(SELECT id FROM ${LocalRows.outbox} WHERE $stale)',
      args,
    );
    return txn.rawDelete('DELETE FROM ${LocalRows.outbox} WHERE $stale', args);
  });

  static Future<void> _deleteOutbox(Transaction txn, String userId) async {
    await txn.rawDelete(
      'DELETE FROM ${LocalRows.outboxFiles} WHERE outbox_id IN '
      '(SELECT id FROM ${LocalRows.outbox} WHERE user_id = ?)',
      [userId],
    );
    await txn.delete(
      LocalRows.outbox,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  @override
  Future<void> deleteOutbox(String userId) =>
      _db.transaction((txn) => _deleteOutbox(txn, userId));

  @override
  Future<void> wipeUser(String userId) => _db.transaction((txn) async {
    for (final table in [LocalRows.cache, LocalRows.drafts]) {
      await txn.delete(table, where: 'user_id = ?', whereArgs: [userId]);
    }
    await _deleteOutbox(txn, userId);
  });

  @override
  Future<void> close() => _db.close();
}
