import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/sqflite_local_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A clock the test moves by hand.
class TestClock {
  DateTime now = DateTime(2026, 10, 17, 9);

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
}

/// A local store implementation the same tests run against. [skip] says
/// why it cannot run on this machine.
class StoreBackend {
  const StoreBackend(this.name, this.open, {this.skip});

  final String name;

  /// Opens a store on [clock]. Queued files are left on disk unless a test
  /// passes [deleteFile].
  final Future<LocalStore> Function(TestClock clock, {DeleteFile? deleteFile})
  open;
  final String? skip;
}

/// The memory store, and the SQLite store through sqflite_common_ffi when
/// the machine's SQLite loads.
Future<List<StoreBackend>> storeBackends() async => [
  StoreBackend(
    'memory',
    (clock, {deleteFile}) async =>
        MemoryLocalStore(clock: clock.call, deleteFile: deleteFile ?? keepFile),
  ),
  StoreBackend(
    'sqflite',
    (clock, {deleteFile}) => openFileStore(clock, deleteFile: deleteFile),
    skip: await sqliteMissing(),
  ),
];

/// Deletes nothing, so a test's made-up paths never reach the disk.
Future<void> keepFile(String path) async {}

/// Notes each path the store deletes, in order.
class DeletedFiles {
  final paths = <String>[];

  Future<void> call(String path) async => paths.add(path);
}

Future<String?> sqliteMissing() async {
  try {
    sqfliteFfiInit();
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    await db.close();
    return null;
  } catch (_) {
    return 'SQLite does not load on this machine';
  }
}

/// A file for a SQLite store, removed after the test.
String storeFile() {
  final dir = Directory.systemTemp.createTempSync('iqly_store_');
  addTearDown(() => dir.delete(recursive: true));
  return '${dir.path}${Platform.pathSeparator}local.db';
}

Future<SqfliteLocalStore> openFileStore(
  TestClock clock, {
  String? path,
  DeleteFile? deleteFile,
}) async {
  final store = await SqfliteLocalStore.open(
    path: path ?? storeFile(),
    factory: databaseFactoryFfiNoIsolate,
    clock: clock.call,
    deleteFile: deleteFile ?? keepFile,
  );
  addTearDown(store.close);
  return store;
}
