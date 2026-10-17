import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import 'local_store.dart';
import 'memory_local_store.dart';
import 'outbox.dart';
import 'sqflite_local_store.dart';

/// The phone's local store: in memory by default, so tests stay offline.
/// The app overrides it with [openLocalStore].
final localStoreProvider = Provider<LocalStore>(
  (ref) => MemoryLocalStore(clock: ref.watch(clockProvider)),
);

/// The outbox on [localStoreProvider]. Live services register their
/// handlers on it; the app starts it for the signed-in person.
final outboxProvider = Provider<Outbox>((ref) {
  final outbox = Outbox(
    ref.watch(localStoreProvider),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(outbox.dispose);
  return outbox;
});

/// The outbox's pending count and failed items, for screens.
final outboxStateProvider = StreamProvider<OutboxState>(
  (ref) => ref.watch(outboxProvider).watch(),
);

/// The store for this phone: its own SQLite on Android and iOS, memory
/// everywhere else.
Future<LocalStore> openLocalStore() async =>
    Platform.isAndroid || Platform.isIOS
    ? await SqfliteLocalStore.open()
    : MemoryLocalStore();
