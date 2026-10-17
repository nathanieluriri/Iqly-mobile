import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';

void main() {
  final now = DateTime(2026, 10, 17, 9);

  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('tests get a memory store on the app clock', () async {
    final store = container().read(localStoreProvider);
    expect(store, isA<MemoryLocalStore>());
    final item = await store.enqueue('u1', kind: 'note', payload: {});
    expect(item.createdAt, now);
  });

  test('the outbox sends through the store it is built on', () async {
    final c = container();
    final outbox = c.read(outboxProvider)
      ..register('note', (item) async => const OutboxResult.done('n_1'));
    await outbox.start('u1');
    final item = await outbox.enqueue('u1', kind: 'note', payload: {});
    await outbox.kick();
    final done = await c.read(localStoreProvider).outboxItem(item.id);
    expect(done!.serverRef, 'n_1');
  });

  test('screens read the pending count from outboxStateProvider', () async {
    final c = container();
    final pending = <int>[];
    c.listen(
      outboxStateProvider,
      (_, next) => next.whenData((state) => pending.add(state.pending)),
      fireImmediately: true,
    );
    final outbox = c.read(outboxProvider);
    await outbox.start('u1');
    await outbox.enqueue('u1', kind: 'poll.vote', payload: {});
    await pumpEventQueue();
    expect(pending.first, 0);
    expect(pending.last, 1);
  });

  test(
    'a phone that is neither Android nor iOS keeps its store in memory',
    () async {
      expect(await openLocalStore(), isA<MemoryLocalStore>());
    },
  );
}
