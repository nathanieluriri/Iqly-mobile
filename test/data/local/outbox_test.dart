import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';

import '../../support/local_stores.dart';

Map<String, Object?> _merge(
  Map<String, dynamic> older,
  Map<String, dynamic> newer,
) => {...older, ...newer};

Future<void> main() async {
  group('outboxResultFor', () {
    const minute = Duration(minutes: 1);

    test('sends again on no answer, 5xx, 429 and timeouts', () {
      expect(
        outboxResultFor(status: 0, networkError: true),
        const OutboxResult.retry(code: OutboxCodes.network),
      );
      expect(
        outboxResultFor(status: 500),
        const OutboxResult.retry(code: 'HTTP_500'),
      );
      expect(
        outboxResultFor(status: 502, code: 'UPSTREAM', message: 'Try again'),
        const OutboxResult.retry(code: 'UPSTREAM', message: 'Try again'),
      );
      expect(
        outboxResultFor(status: 503, retryAfter: minute),
        const OutboxResult.retry(after: minute, code: 'HTTP_503'),
      );
      expect(
        outboxResultFor(status: 429, code: 'RATE_LIMITED', retryAfter: minute),
        const OutboxResult.retry(after: minute, code: 'RATE_LIMITED'),
      );
      expect(
        outboxResultFor(status: 408),
        const OutboxResult.retry(code: 'HTTP_408'),
      );
    });

    test('done on 2xx and on a duplicate submission', () {
      expect(outboxResultFor(status: 200), const OutboxResult.done());
      expect(
        outboxResultFor(status: 201, serverRef: 's_1'),
        const OutboxResult.done('s_1'),
      );
      expect(
        outboxResultFor(
          status: 409,
          code: 'SUBMISSION_DUPLICATE',
          serverRef: 's_1',
        ),
        const OutboxResult.done('s_1'),
      );
    });

    test('holds the queue on 401 and on a closing account', () {
      expect(
        outboxResultFor(status: 401, code: 'UNAUTHORIZED'),
        const OutboxResult.pauseForSignIn(),
      );
      expect(
        outboxResultFor(status: 403, code: 'ACCOUNT_CLOSING'),
        const OutboxResult.pauseForClosing(),
      );
    });

    test('fails on any other 4xx, with its code', () {
      expect(
        outboxResultFor(status: 403, code: 'UNDER_AGE', message: 'Under 18'),
        const OutboxResult.fail('UNDER_AGE', 'Under 18'),
      );
      expect(
        outboxResultFor(status: 409, code: 'PROFILE_INCOMPLETE'),
        const OutboxResult.fail('PROFILE_INCOMPLETE'),
      );
      expect(
        outboxResultFor(status: 422, code: 'VALIDATION_ERROR'),
        const OutboxResult.fail('VALIDATION_ERROR'),
      );
      expect(outboxResultFor(status: 404), const OutboxResult.fail('HTTP_404'));
    });
  });

  test('retries wait a random time up to 2 s, doubling with each failure '
      'and capped at 15 minutes', () {
    final random = Random(42);
    const ceilings = {
      1: Duration(seconds: 2),
      2: Duration(seconds: 4),
      3: Duration(seconds: 8),
      9: Duration(seconds: 512),
      10: Duration(minutes: 15),
      40: Duration(minutes: 15),
    };
    for (final MapEntry(key: attempts, value: ceiling) in ceilings.entries) {
      final waits = [
        for (var i = 0; i < 500; i++) outboxRetryDelay(attempts, random),
      ];
      expect(
        waits.every((wait) => !wait.isNegative && wait < ceiling),
        isTrue,
        reason: 'after $attempts failures',
      );
      expect(
        waits.any((wait) => wait > ceiling * 0.9),
        isTrue,
        reason: 'after $attempts failures',
      );
      expect(
        waits.any((wait) => wait < ceiling * 0.1),
        isTrue,
        reason: 'after $attempts failures',
      );
    }
  });

  for (final backend in await storeBackends()) {
    group('outbox on the ${backend.name} store', () {
      late TestClock clock;
      late LocalStore store;
      late Outbox outbox;
      late List<String> sent;

      setUp(() async {
        clock = TestClock();
        store = await backend.open(clock);
        outbox = Outbox(store, clock: clock.call, random: Random(7));
        addTearDown(outbox.dispose);
        sent = [];
      });

      /// Answers each send of [kind] with the next of [answers], repeating
      /// the last.
      void answer(String kind, List<OutboxResult> answers) {
        var sends = 0;
        outbox.register(kind, (item) async {
          sent.add(item.payload['label'] as String);
          return answers[min(sends++, answers.length - 1)];
        });
      }

      Future<OutboxItem> queue(
        String label, {
        String kind = 'note',
        String user = 'u1',
        String? dependsOn,
      }) => outbox.enqueue(
        user,
        kind: kind,
        payload: {'label': label},
        dependsOn: dependsOn,
      );

      Future<OutboxItem> stored(OutboxItem item) async =>
          (await store.outboxItem(item.id))!;

      test('sends one item at a time, oldest first', () async {
        var inFlight = 0;
        var most = 0;
        outbox.register('note', (item) async {
          most = max(most, ++inFlight);
          sent.add(item.payload['label'] as String);
          await Future<void>.delayed(Duration.zero);
          inFlight--;
          return const OutboxResult.done();
        });
        for (final label in ['A', 'B', 'C']) {
          await queue(label);
        }
        await outbox.start('u1');
        expect(sent, ['A', 'B', 'C']);
        expect(most, 1);
        expect(outbox.state.pending, 0);
      });

      test('an item waits for the one it depends on', () async {
        answer('bank', [
          const OutboxResult.retry(after: Duration(seconds: 5)),
          const OutboxResult.done('b_1'),
        ]);
        answer('withdraw', [const OutboxResult.done('w_1')]);
        final bank = await queue('bank', kind: 'bank');
        final withdraw = await queue(
          'withdraw',
          kind: 'withdraw',
          dependsOn: bank.id,
        );
        await outbox.start('u1');
        expect(sent, ['bank']);
        expect((await stored(withdraw)).attempts, 0);

        clock.advance(const Duration(seconds: 5));
        await outbox.kick();
        expect(sent, ['bank', 'bank', 'withdraw']);
        expect((await stored(bank)).serverRef, 'b_1');
        expect((await stored(withdraw)).status, OutboxStatus.done);
      });

      test(
        'a failed item fails the items depending on it, the same way',
        () async {
          answer('note', [const OutboxResult.done()]);
          answer('bank', [
            const OutboxResult.fail('VALIDATION_ERROR', 'No bank'),
          ]);
          final bank = await queue('bank', kind: 'bank');
          final withdraw = await queue('withdraw', dependsOn: bank.id);
          final notice = await queue('notice', dependsOn: withdraw.id);
          await queue('other');
          await outbox.start('u1');
          expect(sent, ['bank', 'other']);
          for (final item in [withdraw, notice]) {
            final failed = await stored(item);
            expect(failed.status, OutboxStatus.failed);
            expect(failed.lastErrorCode, 'VALIDATION_ERROR');
            expect(failed.lastErrorMessage, 'No bank');
            expect(failed.attempts, 0);
          }
          expect(
            [for (final i in outbox.state.failed) i.id],
            [bank.id, withdraw.id, notice.id],
          );

          final afterwards = await queue('afterwards', dependsOn: bank.id);
          await outbox.kick();
          expect((await stored(afterwards)).status, OutboxStatus.failed);
          expect(sent, ['bank', 'other']);
          expect(outbox.state.pending, 0);
        },
      );

      test('writes sharing a key fold together, and go out in order', () async {
        final payloads = <Map<String, dynamic>>[];
        outbox.register('profile', (item) async {
          payloads.add(item.payload);
          if (payloads.length == 1) {
            await outbox.enqueue(
              'u1',
              kind: 'profile',
              payload: {'bio': 'Data nerd'},
              coalesceKey: 'profile',
              merge: _merge,
            );
            return const OutboxResult.retry(after: Duration(seconds: 10));
          }
          return const OutboxResult.done();
        });
        for (final change in [
          {'name': 'Ada'},
          {'city': 'Yaba'},
        ]) {
          await outbox.enqueue(
            'u1',
            kind: 'profile',
            payload: change,
            coalesceKey: 'profile',
            merge: _merge,
          );
        }
        await outbox.start('u1');
        expect(payloads, [
          {'name': 'Ada', 'city': 'Yaba'},
        ]);
        expect(outbox.state.pending, 2);

        clock.advance(const Duration(seconds: 10));
        await outbox.kick();
        expect(payloads, [
          {'name': 'Ada', 'city': 'Yaba'},
          {'name': 'Ada', 'city': 'Yaba'},
          {'bio': 'Data nerd'},
        ]);
        expect(outbox.state.pending, 0);
      });

      test('a retry waits a jittered backoff, at most 15 minutes', () async {
        answer('note', [const OutboxResult.retry(code: 'HTTP_503')]);
        final item = await queue('A');
        await outbox.start('u1');
        for (var attempts = 1; attempts <= 12; attempts++) {
          final now = clock.now;
          final waiting = await stored(item);
          expect(waiting.attempts, attempts);
          expect(waiting.status, OutboxStatus.pending);
          expect(waiting.lastErrorCode, 'HTTP_503');
          final wait = waiting.nextAttemptAt.difference(now);
          final ceiling = Duration(
            microseconds: min(
              const Duration(seconds: 2).inMicroseconds << (attempts - 1),
              const Duration(minutes: 15).inMicroseconds,
            ),
          );
          expect(wait.isNegative, isFalse);
          expect(wait <= ceiling, isTrue, reason: '$wait after $attempts');

          clock.now = waiting.nextAttemptAt.subtract(
            const Duration(microseconds: 1),
          );
          await outbox.kick();
          expect(sent, hasLength(attempts));
          clock.now = waiting.nextAttemptAt;
          await outbox.kick();
          expect(sent, hasLength(attempts + 1));
        }
      });

      test('Retry-After sets the next attempt', () async {
        answer('note', [
          outboxResultFor(
            status: 429,
            code: 'RATE_LIMITED',
            retryAfter: const Duration(seconds: 30),
          ),
          const OutboxResult.done(),
        ]);
        final item = await queue('A');
        await outbox.start('u1');
        final waiting = await stored(item);
        expect(
          waiting.nextAttemptAt,
          clock.now.add(const Duration(seconds: 30)),
        );
        expect(waiting.lastErrorCode, 'RATE_LIMITED');

        clock.advance(const Duration(seconds: 29));
        await outbox.kick();
        expect(sent, ['A']);
        clock.advance(const Duration(seconds: 1));
        await outbox.kick();
        expect(sent, ['A', 'A']);
        expect((await stored(item)).status, OutboxStatus.done);
      });

      test(
        'gives up on an item still failing a day after it was queued',
        () async {
          answer('note', [outboxResultFor(status: 0, networkError: true)]);
          final item = await queue('A');
          await outbox.start('u1');
          clock.advance(const Duration(hours: 23, minutes: 59));
          await outbox.kick();
          expect(sent, ['A', 'A']);
          expect((await stored(item)).status, OutboxStatus.pending);

          clock.advance(const Duration(minutes: 2));
          await outbox.kick();
          final failed = await stored(item);
          expect(sent, ['A', 'A', 'A']);
          expect(failed.status, OutboxStatus.failed);
          expect(failed.lastErrorCode, OutboxCodes.expired);
          expect(failed.lastErrorMessage, OutboxCodes.network);
          expect(outbox.state.failed.single.id, item.id);
        },
      );

      test(
        '401 holds the whole queue until resume, keeping the items',
        () async {
          answer('note', [
            outboxResultFor(status: 401, code: 'UNAUTHORIZED'),
            const OutboxResult.done(),
          ]);
          answer('other', [const OutboxResult.done()]);
          final first = await queue('A');
          await queue('B', kind: 'other');
          await outbox.start('u1');
          expect(sent, ['A']);
          expect(outbox.state.pause, OutboxPause.signIn);
          expect(outbox.state.pending, 2);
          final held = await stored(first);
          expect(held.status, OutboxStatus.pending);
          expect(held.lastErrorCode, 'UNAUTHORIZED');

          clock.advance(const Duration(hours: 1));
          await outbox.kick();
          await queue('C', kind: 'other');
          await outbox.kick();
          expect(sent, ['A']);

          await outbox.resume();
          expect(sent, ['A', 'A', 'B', 'C']);
          expect(outbox.state.pause, isNull);
          expect(outbox.state.pending, 0);
        },
      );

      test(
        'ACCOUNT_CLOSING holds the queue until the account is restored',
        () async {
          answer('note', [
            outboxResultFor(status: 403, code: 'ACCOUNT_CLOSING'),
            const OutboxResult.done(),
          ]);
          await queue('A');
          await queue('B');
          await outbox.start('u1');
          expect(sent, ['A']);
          expect(outbox.state.pause, OutboxPause.closing);
          await outbox.kick();
          expect(sent, ['A']);

          await outbox.resume();
          expect(sent, ['A', 'A', 'B']);
          expect(outbox.state.pause, isNull);
        },
      );

      test('a refusal fails at once and is not sent again', () async {
        answer('note', [
          outboxResultFor(
            status: 422,
            code: 'VALIDATION_ERROR',
            message: 'Title is required',
          ),
        ]);
        final item = await queue('A');
        await outbox.start('u1');
        final failed = await stored(item);
        expect(failed.status, OutboxStatus.failed);
        expect(failed.lastErrorCode, 'VALIDATION_ERROR');
        expect(failed.lastErrorMessage, 'Title is required');
        expect(failed.attempts, 1);

        clock.advance(const Duration(days: 1));
        await outbox.kick();
        expect(sent, ['A']);
        expect(outbox.state.pending, 0);
        expect(outbox.state.failed.single.id, item.id);
      });

      test('a duplicate submission counts as done', () async {
        answer('submission', [
          outboxResultFor(
            status: 409,
            code: 'SUBMISSION_DUPLICATE',
            serverRef: 's_1',
          ),
        ]);
        final item = await queue('A', kind: 'submission');
        await outbox.start('u1');
        final done = await stored(item);
        expect(done.status, OutboxStatus.done);
        expect(done.serverRef, 's_1');
        expect(outbox.state.failed, isEmpty);
      });

      test('a send a killed app left behind goes again at start', () async {
        final item = await store.enqueue(
          'u1',
          kind: 'note',
          payload: {'label': 'A'},
        );
        await store.markSending(item.id);
        answer('note', [const OutboxResult.done()]);
        await outbox.start('u1');
        expect(sent, ['A']);
        final done = await stored(item);
        expect(done.status, OutboxStatus.done);
        expect(done.attempts, 2);
      });

      test('a handler that throws is tried again later', () async {
        outbox.register('note', (item) async => throw StateError('no file'));
        final item = await queue('A');
        await outbox.start('u1');
        final waiting = await stored(item);
        expect(waiting.status, OutboxStatus.pending);
        expect(waiting.lastErrorCode, OutboxCodes.crashed);
        expect(waiting.lastErrorMessage, contains('no file'));
        expect(waiting.nextAttemptAt.isBefore(clock.now), isFalse);
      });

      test('items with no handler wait without holding up the rest', () async {
        answer('note', [const OutboxResult.done()]);
        final later = await queue('later', kind: 'poll.vote');
        await queue('A');
        await outbox.start('u1');
        expect(sent, ['A']);
        expect((await stored(later)).attempts, 0);
        expect(outbox.state.pending, 1);

        answer('poll.vote', [const OutboxResult.done()]);
        await pumpEventQueue();
        expect(sent, ['A', 'later']);
      });

      test('a write queued while running goes out at once', () async {
        answer('note', [const OutboxResult.done()]);
        await outbox.start('u1');
        final item = await queue('A');
        await pumpEventQueue();
        expect(sent, ['A']);
        expect((await stored(item)).status, OutboxStatus.done);
      });

      test('only the started person\'s items go', () async {
        answer('note', [const OutboxResult.done()]);
        final theirs = await queue('theirs', user: 'u2');
        await queue('mine');
        await outbox.start('u1');
        expect(sent, ['mine']);
        expect((await stored(theirs)).status, OutboxStatus.pending);

        await outbox.stop();
        await queue('kept');
        expect(sent, ['mine']);
        expect(outbox.state.pending, 0);
        expect(await store.outbox('u1'), hasLength(1));

        await outbox.start('u2');
        expect(sent, ['mine', 'theirs']);
      });

      test('a kick while sending joins the run under way', () async {
        final reply = Completer<OutboxResult>();
        addTearDown(() {
          if (!reply.isCompleted) reply.complete(const OutboxResult.done());
        });
        var sends = 0;
        outbox.register('note', (item) {
          sends++;
          return reply.future;
        });
        await outbox.start('u1');
        await queue('A');
        final first = outbox.kick();
        final second = outbox.kick();
        expect(identical(first, second), isTrue);
        await pumpEventQueue();
        expect(sends, 1);
        await queue('waits', kind: 'poll.vote');
        expect(outbox.state.pending, 2);

        reply.complete(const OutboxResult.done());
        await first;
        expect(sends, 1);
        expect(outbox.state.pending, 1);
      });

      test('screens see the pending count and the failed items', () async {
        final states = <OutboxState>[];
        final watching = outbox.watch().listen(states.add);
        addTearDown(watching.cancel);
        answer('note', [const OutboxResult.fail('VALIDATION_ERROR')]);
        await outbox.start('u1');
        await queue('waits', kind: 'poll.vote');
        final refused = await queue('A');
        await outbox.kick();
        await pumpEventQueue();
        expect(states.first.pending, 0);
        expect(states.map((s) => s.pending), contains(2));
        expect(states.last.pending, 1);
        expect(states.last.failed.single.id, refused.id);
      });
    }, skip: backend.skip);
  }

  group('outbox timer', () {
    late List<String> sent;

    Outbox open(FakeAsync async) {
      final start = DateTime(2026, 10, 17, 9);
      DateTime now() => start.add(async.elapsed);
      sent = [];
      return Outbox(
        MemoryLocalStore(clock: now),
        clock: now,
        random: Random(7),
      );
    }

    test('sends a retry when it is due, with no kick', () {
      fakeAsync((async) {
        final outbox = open(async);
        outbox.register('note', (item) async {
          sent.add('A');
          return sent.length == 1
              ? const OutboxResult.retry(after: Duration(seconds: 30))
              : const OutboxResult.done();
        });
        outbox.start('u1');
        outbox.enqueue('u1', kind: 'note', payload: {});
        async.flushMicrotasks();
        expect(sent, ['A']);
        async.elapse(const Duration(seconds: 29));
        expect(sent, ['A']);
        async.elapse(const Duration(seconds: 1));
        expect(sent, ['A', 'A']);
        expect(outbox.state.pending, 0);
        outbox.dispose();
        async.flushMicrotasks();
      });
    });

    test('backs off until the item goes', () {
      fakeAsync((async) {
        final outbox = open(async);
        outbox.register('note', (item) async {
          sent.add('A');
          return sent.length < 5
              ? const OutboxResult.retry()
              : const OutboxResult.done();
        });
        outbox.enqueue('u1', kind: 'note', payload: {});
        outbox.start('u1');
        async.elapse(const Duration(seconds: 30));
        expect(sent, hasLength(5));
        expect(outbox.state.pending, 0);
        expect(async.pendingTimers, isEmpty);
        outbox.dispose();
        async.flushMicrotasks();
      });
    });

    test('nothing goes while paused', () {
      fakeAsync((async) {
        final outbox = open(async);
        outbox.register('note', (item) async {
          sent.add('A');
          return const OutboxResult.retry(after: Duration(seconds: 30));
        });
        outbox.register('other', (item) async {
          sent.add('B');
          return const OutboxResult.pauseForSignIn();
        });
        outbox.enqueue('u1', kind: 'note', payload: {});
        outbox.enqueue('u1', kind: 'other', payload: {});
        outbox.start('u1');
        async.flushMicrotasks();
        expect(sent, ['A', 'B']);
        expect(async.pendingTimers, isEmpty);
        async.elapse(const Duration(minutes: 5));
        expect(sent, ['A', 'B']);

        outbox.resume();
        async.flushMicrotasks();
        expect(sent, ['A', 'B', 'A', 'B']);
        outbox.dispose();
        async.flushMicrotasks();
      });
    });

    test('nothing goes once stopped', () {
      fakeAsync((async) {
        final outbox = open(async);
        outbox.register('note', (item) async {
          sent.add('A');
          return const OutboxResult.retry(after: Duration(seconds: 30));
        });
        outbox.start('u1');
        outbox.enqueue('u1', kind: 'note', payload: {});
        async.flushMicrotasks();
        expect(sent, ['A']);
        expect(async.pendingTimers, hasLength(1));

        outbox.stop();
        async.flushMicrotasks();
        expect(async.pendingTimers, isEmpty);
        outbox.kick();
        outbox.resume();
        async.elapse(const Duration(minutes: 5));
        expect(sent, ['A']);
        outbox.dispose();
        async.flushMicrotasks();
      });
    });
  });
}
