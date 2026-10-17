import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';

import '../../support/local_stores.dart';
import '../../support/outbox_fakes.dart';

Map<String, Object?> _merge(
  Map<String, dynamic> older,
  Map<String, dynamic> newer,
) => {...older, ...newer};

const _photo = OutboxFile(
  localPath: '/data/outbox/photo.jpg',
  bytes: 48213,
  mime: 'image/jpeg',
);

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

    test('holds the queue on 401, a closing account and 426', () {
      expect(
        outboxResultFor(status: 401, code: 'UNAUTHORIZED'),
        const OutboxResult.pauseForSignIn(),
      );
      expect(
        outboxResultFor(status: 403, code: 'ACCOUNT_CLOSING'),
        const OutboxResult.pauseForClosing(),
      );
      expect(
        outboxResultFor(status: 426, code: 'UPGRADE_REQUIRED'),
        const OutboxResult.pauseForUpgrade(),
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
    for (final MapEntry(key: failures, value: ceiling) in ceilings.entries) {
      final waits = [
        for (var i = 0; i < 500; i++) outboxRetryDelay(failures, random),
      ];
      expect(
        waits.every((wait) => !wait.isNegative && wait < ceiling),
        isTrue,
        reason: 'after $failures failures',
      );
      expect(
        waits.any((wait) => wait > ceiling * 0.9),
        isTrue,
        reason: 'after $failures failures',
      );
      expect(
        waits.any((wait) => wait < ceiling * 0.1),
        isTrue,
        reason: 'after $failures failures',
      );
    }
  });

  test('the waits before an item gives up add up to about a day', () {
    for (var seed = 0; seed < 50; seed++) {
      final random = Random(seed);
      var total = Duration.zero;
      for (var failures = 1; failures < Outbox.maxFailures; failures++) {
        total += outboxRetryDelay(failures, random);
      }
      expect(total, greaterThan(const Duration(hours: 20)), reason: '$seed');
      expect(total, lessThan(const Duration(hours: 28)), reason: '$seed');
    }
  });

  for (final backend in await storeBackends()) {
    group('outbox on the ${backend.name} store', () {
      late TestClock clock;
      late DeletedFiles deleted;
      late LocalStore store;
      late Outbox outbox;
      late List<String> sent;
      final lost = outboxResultFor(status: 0, networkError: true);

      setUp(() async {
        clock = TestClock();
        deleted = DeletedFiles();
        store = await backend.open(clock, deleteFile: deleted.call);
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

      /// Moves the clock on by the longest wait and kicks, until [label] has
      /// gone [sends] times in all.
      Future<void> sendUntil(String label, int sends) async {
        while (sent.where((l) => l == label).length < sends) {
          clock.advance(outboxLongestWait);
          await outbox.kick();
        }
      }

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

      group('giving up', () {
        test('comes at the 200th failure in a row', () async {
          answer('note', [lost]);
          final item = await queue('A');
          await outbox.start('u1');
          final began = clock.now;
          await sendUntil('A', Outbox.maxFailures - 1);
          final waiting = await stored(item);
          expect(waiting.status, OutboxStatus.pending);
          expect(waiting.failures, Outbox.maxFailures - 1);
          expect(waiting.failingSince, began);
          expect(outbox.state.failed, isEmpty);

          clock.advance(outboxLongestWait);
          await outbox.kick();
          final failed = await stored(item);
          expect(sent, hasLength(200));
          expect(failed.status, OutboxStatus.failed);
          expect(failed.lastErrorCode, OutboxCodes.expired);
          expect(failed.lastErrorMessage, OutboxCodes.network);
          expect(outbox.state.failed.single.id, item.id);
          expect(Outbox.maxFailures, 200);
        });

        test('does not count time, however far the clock moves, and fails '
            'the dependants with the item', () async {
          answer('upload', [lost]);
          answer('submission', [const OutboxResult.done('s_1')]);
          final upload = await queue('upload', kind: 'upload');
          final submission = await queue(
            'submission',
            kind: 'submission',
            dependsOn: upload.id,
          );
          await outbox.start('u1');
          clock.advance(const Duration(days: 2));
          await outbox.kick();
          expect(sent, ['upload', 'upload']);
          final waiting = await stored(upload);
          expect(waiting.status, OutboxStatus.pending);
          expect(waiting.failures, 2);
          expect((await stored(submission)).status, OutboxStatus.pending);

          clock.now = clock.now.subtract(const Duration(days: 365));
          await sendUntil('upload', Outbox.maxFailures - 1);
          expect((await stored(upload)).status, OutboxStatus.pending);
          clock.advance(outboxLongestWait);
          await outbox.kick();
          expect(sent, hasLength(Outbox.maxFailures));
          expect((await stored(upload)).lastErrorCode, OutboxCodes.expired);
          final failed = await stored(submission);
          expect(failed.status, OutboxStatus.failed);
          expect(failed.lastErrorCode, OutboxCodes.expired);
          expect(failed.attempts, 0);
        });

        test('waits out a Retry-After on a write queued days ago', () async {
          answer('note', [
            outboxResultFor(
              status: 429,
              code: 'RATE_LIMITED',
              retryAfter: const Duration(seconds: 30),
            ),
            const OutboxResult.done(),
          ]);
          final item = await queue('A');
          clock.advance(const Duration(hours: 30));
          await outbox.start('u1');
          expect((await stored(item)).status, OutboxStatus.pending);
          clock.advance(const Duration(seconds: 30));
          await outbox.kick();
          expect((await stored(item)).status, OutboxStatus.done);
        });

        test('a dependant counts its own failures', () async {
          var uploads = 0;
          outbox.register('upload', (item) async {
            sent.add('upload');
            return ++uploads < 150 ? lost : const OutboxResult.done('up_1');
          });
          answer('submission', [outboxResultFor(status: 503)]);
          final upload = await queue('upload', kind: 'upload');
          final submission = await queue(
            'submission',
            kind: 'submission',
            dependsOn: upload.id,
          );
          await outbox.start('u1');
          await sendUntil('upload', 150);
          expect((await stored(upload)).status, OutboxStatus.done);
          await sendUntil('submission', Outbox.maxFailures - 1);
          final waiting = await stored(submission);
          expect(waiting.status, OutboxStatus.pending);
          expect(waiting.failures, Outbox.maxFailures - 1);
        });

        test('starts again for every unsent write when the queue '
            'pauses', () async {
          var signedIn = true;
          answer('note', [outboxResultFor(status: 503)]);
          outbox.register('other', (item) async {
            sent.add('B');
            return signedIn
                ? const OutboxResult.done()
                : outboxResultFor(status: 401);
          });
          final failing = await queue('A');
          await outbox.start('u1');
          await sendUntil('A', 150);
          expect((await stored(failing)).failures, 150);

          signedIn = false;
          await queue('B', kind: 'other');
          await outbox.kick();
          expect(outbox.state.pause, OutboxPause.signIn);
          final paused = await stored(failing);
          expect(paused.failures, 0);
          expect(paused.failingSince, isNull);

          clock.advance(const Duration(days: 7));
          signedIn = true;
          await outbox.resume();
          final waiting = await stored(failing);
          expect(waiting.status, OutboxStatus.pending);
          expect(waiting.failures, 1);
          expect(waiting.failingSince, clock.now);
          expect(sent.where((l) => l == 'B'), hasLength(2));

          await sendUntil('A', 150 + Outbox.maxFailures - 1);
          expect((await stored(failing)).status, OutboxStatus.pending);
          clock.advance(outboxLongestWait);
          await outbox.kick();
          expect((await stored(failing)).lastErrorCode, OutboxCodes.expired);
        });

        test('backs off by failures in a row, so a pause starts the waits '
            'short again', () async {
          var signedIn = true;
          outbox.register('note', (item) async {
            sent.add('A');
            return signedIn
                ? outboxResultFor(status: 503)
                : outboxResultFor(status: 401);
          });
          final item = await queue('A');
          await outbox.start('u1');
          await sendUntil('A', 12);
          signedIn = false;
          clock.advance(outboxLongestWait);
          await outbox.kick();
          expect(outbox.state.pause, OutboxPause.signIn);

          signedIn = true;
          await outbox.resume();
          final waiting = await stored(item);
          expect(waiting.failures, 1);
          expect(waiting.attempts, 14);
          expect(
            waiting.nextAttemptAt.difference(clock.now),
            lessThan(const Duration(seconds: 2)),
          );
        });
      });

      group('folding', () {
        test('a write naming no dependency does not take on the one of the '
            'write before it', () async {
          answer('upload', [
            outboxResultFor(
              status: 413,
              code: 'FILE_TOO_LARGE',
              message: 'Avatar photos are 1 MB at most',
            ),
          ]);
          answer('avatar.photo', [const OutboxResult.done()]);
          answer('avatar.preset', [const OutboxResult.done()]);
          final upload = await outbox.enqueue(
            'u1',
            kind: 'upload',
            payload: {'label': 'upload'},
            files: const [_photo],
          );
          final photo = await outbox.enqueue(
            'u1',
            kind: 'avatar.photo',
            payload: {'label': 'photo', 'upload': upload.id},
            coalesceKey: 'avatar',
            dependsOn: upload.id,
          );
          final preset = await outbox.enqueue(
            'u1',
            kind: 'avatar.preset',
            payload: {'label': 'preset', 'preset': 'p3'},
            coalesceKey: 'avatar',
          );
          expect(preset.id, isNot(photo.id));
          expect(preset.dependsOn, isNull);

          await outbox.start('u1');
          expect(sent, ['upload', 'preset']);
          final refused = await stored(photo);
          expect(refused.status, OutboxStatus.failed);
          expect(refused.lastErrorCode, 'FILE_TOO_LARGE');
          expect((await stored(preset)).status, OutboxStatus.done);
        });

        test('a newer write\'s files replace the older ones, none '
            'included', () async {
          final files = <List<String>>[];
          outbox.register('submission', (item) async {
            sent.add(item.payload['label'] as String);
            files.add([for (final f in item.files) f.localPath]);
            return const OutboxResult.done('s_1');
          });
          await outbox.enqueue(
            'u1',
            kind: 'submission',
            payload: {'label': 'with the photo', 'attachments': 1},
            coalesceKey: 'submit:c_1',
            merge: _merge,
            files: const [_photo],
          );
          await outbox.enqueue(
            'u1',
            kind: 'submission',
            payload: {'label': 'without it', 'attachments': 0},
            coalesceKey: 'submit:c_1',
            merge: _merge,
          );
          expect(deleted.paths, [_photo.localPath]);
          await outbox.start('u1');
          expect(sent, ['without it']);
          expect(files, [<String>[]]);
        });
      });

      group('try again and discard', () {
        test('try again gives a failed item its tries again', () async {
          answer('note', [lost]);
          final item = await queue('A');
          await outbox.start('u1');
          await sendUntil('A', Outbox.maxFailures);
          expect((await stored(item)).status, OutboxStatus.failed);

          expect(await outbox.retry(item.id), isTrue);
          await pumpEventQueue();
          final waiting = await stored(item);
          expect(sent, hasLength(Outbox.maxFailures + 1));
          expect(waiting.status, OutboxStatus.pending);
          expect(waiting.failures, 1);
          expect(waiting.failingSince, clock.now);
          expect(outbox.state.failed, isEmpty);
          expect(outbox.state.pending, 1);
        });

        test('try again leaves an item that has not failed', () async {
          answer('note', [const OutboxResult.done()]);
          final done = await queue('A');
          final waiting = await queue('B', kind: 'poll.vote');
          await outbox.start('u1');
          for (final id in [done.id, waiting.id, 'nope']) {
            expect(await outbox.retry(id), isFalse);
          }
          expect((await stored(done)).status, OutboxStatus.done);
          expect((await stored(waiting)).attempts, 0);
        });

        test('try again sends the failed items an item depends on first, '
            'and leaves the ones depending on it', () async {
          var refuse = true;
          outbox.register('upload', (item) async {
            sent.add('upload');
            return refuse
                ? outboxResultFor(status: 400, code: 'BAD_FILE')
                : const OutboxResult.done('up_1');
          });
          answer('submission', [const OutboxResult.done('s_1')]);
          answer('receipt', [const OutboxResult.done()]);
          final upload = await queue('upload', kind: 'upload');
          final submission = await queue(
            'submission',
            kind: 'submission',
            dependsOn: upload.id,
          );
          final receipt = await queue(
            'receipt',
            kind: 'receipt',
            dependsOn: submission.id,
          );
          await outbox.start('u1');
          expect(sent, ['upload']);
          expect(
            [for (final i in outbox.state.failed) i.id],
            [upload.id, submission.id, receipt.id],
          );

          refuse = false;
          expect(await outbox.retry(submission.id), isTrue);
          await outbox.kick();
          expect(sent, ['upload', 'upload', 'submission']);
          expect((await stored(submission)).serverRef, 's_1');
          expect((await stored(receipt)).lastErrorCode, 'BAD_FILE');

          expect(await outbox.retry(receipt.id), isTrue);
          await outbox.kick();
          expect(sent, ['upload', 'upload', 'submission', 'receipt']);
          expect(outbox.state.failed, isEmpty);
        });

        test('try again puts the items back from the first dependency down, '
            'so a run under way cannot fail them again', () async {
          final gated = GatedStore(store);
          final runner = Outbox(gated, clock: clock.call, random: Random(4));
          addTearDown(runner.dispose);
          var refuse = true;
          runner.register('upload', (item) async {
            sent.add('upload');
            return refuse
                ? outboxResultFor(status: 400, code: 'BAD_FILE')
                : const OutboxResult.done('up_1');
          });
          runner.register('submission', (item) async {
            sent.add('submission');
            return const OutboxResult.done('s_1');
          });
          final upload = await runner.enqueue(
            'u1',
            kind: 'upload',
            payload: {},
          );
          final submission = await runner.enqueue(
            'u1',
            kind: 'submission',
            payload: {},
            dependsOn: upload.id,
          );
          await runner.start('u1');
          expect(sent, ['upload']);

          refuse = false;
          gated.afterRequeue = runner.kick;
          expect(await runner.retry(submission.id), isTrue);
          await runner.kick();
          expect(sent, ['upload', 'upload', 'submission']);
          expect((await stored(submission)).status, OutboxStatus.done);
        });

        test('discard drops a refused write and its files, and keeps the '
            'person\'s other writes', () async {
          answer('vote', [outboxResultFor(status: 422, code: 'POLL_CLOSED')]);
          final vote = await outbox.enqueue(
            'u1',
            kind: 'vote',
            payload: {'label': 'vote'},
            files: const [_photo],
          );
          final support = await queue('support', kind: 'support');
          await outbox.start('u1');
          clock.advance(const Duration(days: 30));
          await outbox.stop();
          await outbox.start('u1');
          expect(outbox.state.failed.single.id, vote.id);
          expect(deleted.paths, isEmpty);

          expect(await outbox.discard(vote.id), isTrue);
          expect(await store.outboxItem(vote.id), isNull);
          expect(deleted.paths, [_photo.localPath]);
          expect(outbox.state.failed, isEmpty);
          expect(outbox.state.pending, 1);
          expect(
            [for (final i in await store.outbox('u1')) i.id],
            [support.id],
          );
        });

        test('discard fails what depends on the item, and it cannot be '
            'tried again', () async {
          answer('submission', [const OutboxResult.done('s_1')]);
          final upload = await queue('upload', kind: 'upload');
          final submission = await queue(
            'submission',
            kind: 'submission',
            dependsOn: upload.id,
          );
          await outbox.start('u1');
          expect(await outbox.discard(upload.id), isTrue);
          final failed = await stored(submission);
          expect(failed.status, OutboxStatus.failed);
          expect(failed.lastErrorCode, OutboxCodes.discarded);
          expect(outbox.state.failed.single.id, submission.id);
          expect(outbox.state.pending, 0);

          expect(await outbox.retry(submission.id), isFalse);
          answer('upload', [const OutboxResult.done('up_1')]);
          await outbox.kick();
          expect(sent, isEmpty);
          expect((await stored(submission)).status, OutboxStatus.failed);
        });

        test('discard lets the write behind it with its key go', () async {
          var first = true;
          outbox.register('prefs', (item) async {
            sent.add(item.payload['label'] as String);
            if (!first) return const OutboxResult.done();
            first = false;
            return outboxResultFor(
              status: 503,
              retryAfter: const Duration(hours: 1),
            );
          });
          Future<OutboxItem> prefs(String label) => outbox.enqueue(
            'u1',
            kind: 'prefs',
            payload: {'label': label},
            coalesceKey: 'prefs',
          );
          await outbox.start('u1');
          final older = await prefs('old');
          await pumpEventQueue();
          await prefs('new');
          await outbox.kick();
          expect(sent, ['old']);

          expect(await outbox.discard(older.id), isTrue);
          await pumpEventQueue();
          expect(sent, ['old', 'new']);
          expect(await store.outbox('u1'), isEmpty);
        });

        test('discard leaves a write on its way', () async {
          final reply = Completer<OutboxResult>();
          addTearDown(() {
            if (!reply.isCompleted) reply.complete(const OutboxResult.done());
          });
          outbox.register('note', (item) => reply.future);
          await outbox.start('u1');
          final item = await queue('A');
          await pumpEventQueue();
          expect(await outbox.discard(item.id), isFalse);
          expect((await stored(item)).status, OutboxStatus.sending);

          reply.complete(const OutboxResult.done());
          await outbox.kick();
          expect((await stored(item)).status, OutboxStatus.done);
        });
      });

      group('a newer write with the key of a failed item', () {
        Future<OutboxItem> prefs(String label, {String user = 'u1'}) =>
            outbox.enqueue(
              user,
              kind: 'prefs',
              payload: {'label': label},
              coalesceKey: 'prefs',
            );

        setUp(() {
          answer('prefs', [
            outboxResultFor(status: 422, code: 'VALIDATION_ERROR'),
            const OutboxResult.done(),
          ]);
        });

        test('supersedes it once it lands, even after its done row is '
            'purged', () async {
          await outbox.start('u1');
          final older = await prefs('old');
          await pumpEventQueue();
          expect((await stored(older)).status, OutboxStatus.failed);
          final newer = await prefs('new');
          await pumpEventQueue();
          expect(sent, ['old', 'new']);
          expect((await stored(newer)).status, OutboxStatus.done);
          expect((await stored(older)).lastErrorCode, OutboxCodes.superseded);

          expect(await outbox.retry(older.id), isFalse);
          await outbox.kick();
          expect(sent, ['old', 'new']);

          await outbox.stop();
          clock.advance(Outbox.keepDone + const Duration(hours: 1));
          final relaunched = Outbox(
            store,
            clock: clock.call,
            random: Random(9),
          );
          addTearDown(relaunched.dispose);
          relaunched.register('prefs', (item) async {
            sent.add(item.payload['label'] as String);
            return const OutboxResult.done();
          });
          await relaunched.start('u1');
          expect(await store.outboxItem(newer.id), isNull);
          expect(await relaunched.retry(older.id), isFalse);
          await relaunched.kick();
          expect(sent, ['old', 'new']);
          final kept = await stored(older);
          expect(kept.status, OutboxStatus.failed);
          expect(relaunched.state.failed.single.id, older.id);
        });

        test('supersedes it while the newer write still waits', () async {
          await outbox.start('u1');
          final older = await prefs('old');
          await pumpEventQueue();
          await outbox.stop();
          final newer = await prefs('new');
          expect((await stored(newer)).status, OutboxStatus.pending);
          expect(await outbox.retry(older.id), isFalse);

          await outbox.start('u1');
          expect(sent, ['old', 'new']);
          expect((await stored(older)).status, OutboxStatus.failed);
        });

        test('leaves it to try again when the write has another key, or is '
            'another person\'s', () async {
          await outbox.start('u1');
          final older = await prefs('old');
          await pumpEventQueue();
          await outbox.stop();
          await outbox.enqueue(
            'u1',
            kind: 'prefs',
            payload: {'label': 'other key'},
            coalesceKey: 'profile',
          );
          await prefs('theirs', user: 'u2');
          await outbox.enqueue('u1', kind: 'prefs', payload: {'label': 'none'});
          expect((await stored(older)).lastErrorCode, 'VALIDATION_ERROR');

          await outbox.start('u1');
          expect(await outbox.retry(older.id), isTrue);
          await outbox.kick();
          expect(sent, ['old', 'other key', 'none', 'old']);
          expect((await stored(older)).status, OutboxStatus.done);
        });

        test('leaves what depends on it unable to try again', () async {
          answer('note', [const OutboxResult.done()]);
          await outbox.start('u1');
          final older = await prefs('old');
          final dependant = await outbox.enqueue(
            'u1',
            kind: 'note',
            payload: {'label': 'after'},
            dependsOn: older.id,
          );
          await pumpEventQueue();
          expect((await stored(dependant)).lastErrorCode, 'VALIDATION_ERROR');
          await prefs('new');
          await pumpEventQueue();

          expect(await outbox.retry(dependant.id), isFalse);
          expect(await outbox.retry(older.id), isFalse);
          await outbox.kick();
          expect(sent, ['old', 'new']);
          expect((await stored(dependant)).status, OutboxStatus.failed);
          expect((await stored(older)).status, OutboxStatus.failed);
        });
      });

      group('a store that fails to record an answer', () {
        late GatedStore gated;
        late Outbox runner;
        late List<String> applied;

        setUp(() {
          gated = GatedStore(store);
          runner = Outbox(gated, clock: clock.call, random: Random(2));
          addTearDown(runner.dispose);
          applied = [];
          runner.register('prefs', (item) async {
            applied.add('${item.payload['polls']}');
            return const OutboxResult.done();
          });
        });

        Future<OutboxItem> prefs(bool polls) => runner.enqueue(
          'u1',
          kind: 'prefs',
          payload: {'polls': polls},
          coalesceKey: 'prefs',
        );

        test('puts the item back in line, and the write behind it with its '
            'key goes after it', () async {
          await runner.start('u1');
          gated.failNextMarkDone = StateError('database or disk is full');
          final first = await prefs(false);
          await pumpEventQueue();
          final back = await stored(first);
          expect(back.status, OutboxStatus.pending);
          expect(back.lastErrorCode, OutboxCodes.storeError);
          expect(back.lastErrorMessage, contains('disk is full'));
          expect(back.failures, 1);
          expect(back.nextAttemptAt.isAfter(clock.now), isTrue);
          expect(
            back.nextAttemptAt.difference(clock.now),
            lessThan(const Duration(seconds: 2)),
          );

          final second = await prefs(true);
          expect(second.id, isNot(first.id));
          clock.advance(const Duration(seconds: 2));
          await runner.kick();
          expect(applied, ['false', 'false', 'true']);
          expect(await store.outbox('u1'), isEmpty);
        });

        test('when it cannot put the item back either, reports the error '
            'and the next launch sends the item again', () async {
          final errors = <Object>[];
          final settled = Completer<void>();
          runZonedGuarded(() async {
            await runner.start('u1');
            gated
              ..failNextMarkDone = StateError('database or disk is full')
              ..failNextMarkRetry = StateError('database or disk is full');
            await prefs(false);
            await pumpEventQueue();
            settled.complete();
          }, (error, _) => errors.add(error));
          await settled.future.timeout(const Duration(seconds: 5));
          expect(errors, [isStateError]);
          final stuck = (await store.outbox('u1')).single;
          expect(stuck.status, OutboxStatus.sending);
          expect(applied, ['false']);

          final relaunched = Outbox(
            store,
            clock: clock.call,
            random: Random(3),
          );
          addTearDown(relaunched.dispose);
          relaunched.register('prefs', (item) async {
            applied.add('${item.payload['polls']}');
            return const OutboxResult.done();
          });
          await relaunched.start('u1');
          expect(applied, ['false', 'false']);
          expect(await store.outbox('u1'), isEmpty);
        });
      });

      group('a change after a send went out', () {
        test('goes under its own key when the answer was lost', () async {
          final server = IdempotentServer();
          var loseAnswer = true;
          outbox.register('proof', (item) async {
            final reply = server.post(item);
            if (!loseAnswer) return reply;
            loseAnswer = false;
            return outboxResultFor(status: 0, networkError: true);
          });
          Future<OutboxItem> photo(String file) => outbox.enqueue(
            'u1',
            kind: 'proof',
            payload: {'resource': 'proof:a_1:1', 'value': file},
            coalesceKey: 'proof:a_1:1',
            merge: _merge,
          );
          await outbox.start('u1');
          final first = await photo('blurry.jpg');
          await pumpEventQueue();
          expect(server.applied, ['u1/proof:a_1:1=blurry.jpg']);

          final retaken = await photo('sharp.jpg');
          expect(retaken.id, isNot(first.id));
          clock.advance(outboxLongestWait);
          await outbox.kick();
          expect(server.requests, [first.id, first.id, retaken.id]);
          expect(server.resources['u1/proof:a_1:1'], 'sharp.jpg');
          expect(await store.outbox('u1'), isEmpty);
        });

        test(
          'goes under its own key after a killed app sent the first',
          () async {
            final server = IdempotentServer();
            Future<OutboxItem> photo(String file) => store.enqueue(
              'u1',
              kind: 'proof',
              payload: {'resource': 'proof:a_1:1', 'value': file},
              coalesceKey: 'proof:a_1:1',
              merge: _merge,
            );
            final first = await photo('blurry.jpg');
            server.post((await store.markSending(first.id))!);

            final retaken = await photo('sharp.jpg');
            expect(retaken.id, isNot(first.id));
            outbox.register('proof', (item) async => server.post(item));
            await outbox.start('u1');
            expect(server.applied, [
              'u1/proof:a_1:1=blurry.jpg',
              'u1/proof:a_1:1=sharp.jpg',
            ]);
            expect(server.resources['u1/proof:a_1:1'], 'sharp.jpg');
            expect(await store.outbox('u1'), isEmpty);
          },
        );
      });

      group('a phone clock set back', () {
        test('does not hold a write queued before it', () async {
          answer('note', [const OutboxResult.done()]);
          final item = await queue('A');
          clock.now = clock.now.subtract(const Duration(days: 1));
          await outbox.start('u1');
          expect(sent, ['A']);
          expect((await stored(item)).status, OutboxStatus.done);
        });

        test('does not stretch a backoff past 15 minutes', () async {
          answer('note', [
            outboxResultFor(status: 0, networkError: true),
            const OutboxResult.done(),
          ]);
          await outbox.start('u1');
          final item = await queue('A');
          await pumpEventQueue();
          expect(sent, ['A']);
          clock.now = clock.now.subtract(const Duration(hours: 6));
          await outbox.kick();
          expect(sent, ['A', 'A']);
          expect((await stored(item)).status, OutboxStatus.done);
        });

        test('lets writes made after it go too', () async {
          answer('profile', [const OutboxResult.done()]);
          Future<OutboxItem> edit(String label) => outbox.enqueue(
            'u1',
            kind: 'profile',
            payload: {'label': label},
            coalesceKey: 'profile',
            merge: _merge,
          );
          await edit('Ada');
          clock.now = clock.now.subtract(const Duration(days: 2));
          await outbox.start('u1');
          await edit('Yaba');
          await pumpEventQueue();
          expect(sent, ['Ada', 'Yaba']);
          expect(await store.outbox('u1'), isEmpty);
        });

        test('still honours a Retry-After longer than 15 minutes', () async {
          answer('note', [
            outboxResultFor(status: 503, retryAfter: const Duration(hours: 1)),
            const OutboxResult.done(),
          ]);
          final item = await queue('A');
          await outbox.start('u1');
          expect((await stored(item)).retryAfter, const Duration(hours: 1));
          clock.advance(const Duration(minutes: 59));
          await outbox.kick();
          expect(sent, ['A']);
          clock.advance(const Duration(minutes: 1));
          await outbox.kick();
          expect(sent, ['A', 'A']);
        });
      });

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

      test('426 holds the queue until the updated app starts it', () async {
        answer('note', [
          outboxResultFor(status: 426, code: 'UPGRADE_REQUIRED'),
          const OutboxResult.done(),
        ]);
        final item = await queue('A');
        await queue('B');
        await outbox.start('u1');
        expect(sent, ['A']);
        expect(outbox.state.pause, OutboxPause.upgrade);
        final held = await stored(item);
        expect(held.status, OutboxStatus.pending);
        expect(held.lastErrorCode, 'UPGRADE_REQUIRED');
        await outbox.kick();
        expect(sent, ['A']);

        await outbox.start('u1');
        expect(sent, ['A', 'A', 'B']);
        expect(outbox.state.pause, isNull);
      });

      group('a pause from a send that began before', () {
        late Completer<OutboxResult> reply;

        setUp(() {
          reply = Completer<OutboxResult>();
          addTearDown(() {
            if (!reply.isCompleted) reply.complete(const OutboxResult.done());
          });
          outbox.register('note', (item) {
            sent.add(item.payload['label'] as String);
            return sent.length == 1
                ? reply.future
                : Future.value(const OutboxResult.done());
          });
        });

        test('signing in again is ignored', () async {
          await outbox.start('u1');
          await queue('A');
          await pumpEventQueue();
          final again = outbox.start('u1');
          await pumpEventQueue();
          reply.complete(const OutboxResult.pauseForSignIn());
          await again;
          await queue('B');
          await outbox.kick();
          expect(outbox.state.pause, isNull);
          expect(sent, ['A', 'A', 'B']);
        });

        test('resume is ignored', () async {
          await outbox.start('u1');
          await queue('A');
          await pumpEventQueue();
          final resumed = outbox.resume();
          reply.complete(outboxResultFor(status: 403, code: 'ACCOUNT_CLOSING'));
          await resumed;
          await outbox.kick();
          expect(outbox.state.pause, isNull);
          expect(sent, ['A', 'A']);
        });
      });

      test('stop does not wait for a send on its way, and a wipe leaves '
          'nothing behind', () async {
        final reply = Completer<OutboxResult>();
        addTearDown(() {
          if (!reply.isCompleted) reply.complete(const OutboxResult.done());
        });
        outbox.register('note', (item) => reply.future);
        await outbox.start('u1');
        final item = await outbox.enqueue(
          'u1',
          kind: 'note',
          payload: {},
          files: const [
            OutboxFile(localPath: '/x/a.jpg', bytes: 1, mime: 'image/jpeg'),
          ],
        );
        await pumpEventQueue();
        var stopped = false;
        unawaited(outbox.stop().then((_) => stopped = true));
        await pumpEventQueue();
        expect(stopped, isTrue);

        await store.wipeUser('u1');
        reply.complete(const OutboxResult.done('n_1'));
        await pumpEventQueue();
        expect(await store.outboxItem(item.id), isNull);
        await outbox.start('u1');
        expect(await store.outbox('u1'), isEmpty);
      });

      test('a write picked before a switch to another person is not sent '
          'in their session', () async {
        final gated = GatedStore(store);
        final switching = Outbox(gated, clock: clock.call, random: Random(5));
        addTearDown(switching.dispose);
        final handed = <String>[];
        switching.register('note', (item) async {
          handed.add(item.userId);
          return const OutboxResult.done();
        });
        await switching.start('u1');
        final gate = gated.dueGate = Completer<void>();
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });
        final mine = await store.enqueue('u1', kind: 'note', payload: {});
        unawaited(switching.kick());
        await pumpEventQueue();
        await switching.stop();
        final theirs = switching.start('u2');
        await pumpEventQueue();
        gated.dueGate = null;
        gate.complete();
        await theirs;
        expect(handed, isEmpty);
        expect((await stored(mine)).status, OutboxStatus.pending);

        await switching.start('u1');
        expect(handed, ['u1']);
      });

      test('a start that fails to recover leaves the next start to try '
          'again', () async {
        final gated = GatedStore(store)
          ..failNextReset = StateError('database is locked');
        final flaky = Outbox(gated, clock: clock.call, random: Random(6));
        addTearDown(flaky.dispose);
        flaky.register('note', (item) async {
          sent.add(item.payload['label'] as String);
          return const OutboxResult.done();
        });
        await store.enqueue('u1', kind: 'note', payload: {'label': 'A'});
        await expectLater(flaky.start('u1'), throwsStateError);
        await flaky.start('u1');
        expect(sent, ['A']);
      });

      test('a send that outlasts the timeout stays on its way while the '
          'queue moves on', () async {
        final watched = Outbox(
          store,
          clock: clock.call,
          random: Random(3),
          sendTimeout: const Duration(milliseconds: 100),
        );
        addTearDown(watched.dispose);
        var uploads = 0;
        watched.register('upload', (item) {
          uploads++;
          return Completer<OutboxResult>().future;
        });
        watched.register('note', (item) async {
          sent.add(item.payload['label'] as String);
          return const OutboxResult.done();
        });
        final upload = await store.enqueue('u1', kind: 'upload', payload: {});
        await store.enqueue('u1', kind: 'note', payload: {'label': 'A'});
        await watched.start('u1');
        expect(sent, ['A']);
        clock.advance(const Duration(hours: 1));
        await watched.kick();
        final onItsWay = await stored(upload);
        expect(onItsWay.status, OutboxStatus.sending);
        expect(onItsWay.attempts, 1);
        expect(uploads, 1);
        expect(watched.state.pending, 1);
      });
    }, skip: backend.skip);
  }

  for (final backend in await storeBackends()) {
    group('outbox timer on the ${backend.name} store', () {
      late List<String> sent;
      late LocalStore store;
      late _FakeTime time;
      var setBack = Duration.zero;

      setUp(() async {
        sent = [];
        setBack = Duration.zero;
        time = _FakeTime();
        store = await backend.open(time);
      });

      Outbox open(FakeAsync async, {int seed = 7}) {
        final start = DateTime(2026, 10, 17, 9);
        time.read = () => start.add(async.elapsed).subtract(setBack);
        return Outbox(store, clock: time.call, random: Random(seed));
      }

      OutboxItem? read(FakeAsync async, String id) {
        OutboxItem? found;
        store.outboxItem(id).then((item) => found = item);
        async.flushMicrotasks();
        return found;
      }

      test('a send that outlasts two minutes is not sent again, and its '
          'answer lands when it comes', () {
        fakeAsync((async) {
          final outbox = open(async);
          final server = IdempotentServer();
          var inFlight = 0;
          var most = 0;
          outbox.register('submission', (item) async {
            most = max(most, ++inFlight);
            await Future<void>.delayed(const Duration(minutes: 3));
            inFlight--;
            return server.post(item);
          });
          outbox.start('u1');
          late OutboxItem item;
          outbox
              .enqueue(
                'u1',
                kind: 'submission',
                payload: {'resource': 'submit:c_1', 'value': 'entry'},
              )
              .then((i) => item = i);
          async.flushMicrotasks();
          async.elapse(const Duration(minutes: 2, seconds: 59));
          expect(read(async, item.id)!.status, OutboxStatus.sending);
          expect(outbox.state.pending, 1);

          async.elapse(const Duration(seconds: 1));
          final done = read(async, item.id)!;
          expect(done.status, OutboxStatus.done);
          expect(done.serverRef, 'r_0');
          expect(done.attempts, 1);
          async.elapse(const Duration(hours: 25));
          expect(server.requests, [item.id]);
          expect(most, 1);
          expect(outbox.state.pending, 0);
          expect(async.pendingTimers, isEmpty);
          outbox.dispose();
          async.flushMicrotasks();
        });
      });

      test('other writes go while a slow send is out; its key and its '
          'dependants wait for its answer', () {
        fakeAsync((async) {
          final outbox = open(async);
          outbox.register('note', (item) async {
            final label = item.payload['label'] as String;
            sent.add('$label @${async.elapsed.inSeconds}');
            if (label == 'slow') {
              await Future<void>.delayed(const Duration(minutes: 5));
            }
            return const OutboxResult.done();
          });
          Future<OutboxItem> queue(
            String label, {
            String? key,
            String? dependsOn,
          }) => outbox.enqueue(
            'u1',
            kind: 'note',
            payload: {'label': label},
            coalesceKey: key,
            dependsOn: dependsOn,
          );
          outbox.start('u1');
          late OutboxItem slow;
          queue('slow', key: 'k').then((i) => slow = i);
          async.flushMicrotasks();
          queue('same key', key: 'k');
          queue('dependant', dependsOn: slow.id);
          queue('other', key: 'l');
          async.flushMicrotasks();
          expect(sent, ['slow @0']);

          async.elapse(const Duration(minutes: 2));
          expect(sent, ['slow @0', 'other @120']);
          expect(outbox.state.pending, 3);
          async.elapse(const Duration(minutes: 3));
          expect(sent, [
            'slow @0',
            'other @120',
            'same key @300',
            'dependant @300',
          ]);
          expect(outbox.state.pending, 0);
          outbox.dispose();
          async.flushMicrotasks();
        });
      });

      for (final stopFirst in [true, false]) {
        test('a start for another person${stopFirst ? ' after a stop' : ''} '
            'does not wait for a send on its way, whose answer lands for '
            'its own person', () {
          fakeAsync((async) {
            final outbox = open(async);
            outbox.register('upload', (item) async {
              sent.add('${item.userId} upload @${async.elapsed.inSeconds}');
              await Future<void>.delayed(const Duration(minutes: 5));
              return const OutboxResult.done('up_1');
            });
            outbox.register('note', (item) async {
              sent.add('${item.userId} note @${async.elapsed.inSeconds}');
              return const OutboxResult.done();
            });
            outbox.start('u1');
            late OutboxItem upload;
            outbox
                .enqueue('u1', kind: 'upload', payload: {}, coalesceKey: 'k')
                .then((i) => upload = i);
            async.elapse(const Duration(seconds: 1));
            if (stopFirst) {
              outbox.stop();
              async.flushMicrotasks();
              expect(async.pendingTimers, hasLength(1));
            }
            outbox.start('u2');
            outbox.enqueue('u2', kind: 'note', payload: {}, coalesceKey: 'k');
            async.elapse(const Duration(seconds: 1));
            expect(sent, ['u1 upload @0', 'u2 note @1']);
            expect(read(async, upload.id)!.status, OutboxStatus.sending);
            expect(outbox.state.pending, 0);

            async.elapse(const Duration(minutes: 5));
            final landed = read(async, upload.id)!;
            expect(landed.status, OutboxStatus.done);
            expect(landed.serverRef, 'up_1');
            expect(sent, hasLength(2));
            outbox.dispose();
            async.flushMicrotasks();
          });
        });
      }

      test('after a sign-out and back in, a write waits for the send its '
          'key still has on its way', () {
        fakeAsync((async) {
          final outbox = open(async);
          final server = IdempotentServer();
          outbox.register('set', (item) async {
            sent.add('${item.payload['value']} @${async.elapsed.inSeconds}');
            if (item.payload['value'] == 'old') {
              await Future<void>.delayed(const Duration(minutes: 5));
            }
            return server.post(item);
          });
          Future<OutboxItem> set(String resource, String value) =>
              outbox.enqueue(
                'u1',
                kind: 'set',
                payload: {'resource': resource, 'value': value},
                coalesceKey: 'set:$resource',
              );
          outbox.start('u1');
          set('name', 'old');
          async.elapse(const Duration(seconds: 1));
          outbox.stop();
          store.wipeUser('u1');
          outbox.start('u1');
          set('name', 'new');
          set('city', 'Yaba');
          async.elapse(const Duration(seconds: 1));
          expect(sent, ['old @0', 'Yaba @1']);

          async.elapse(const Duration(minutes: 5));
          expect(sent, ['old @0', 'Yaba @1', 'new @300']);
          expect(server.applied, [
            'u1/city=Yaba',
            'u1/name=old',
            'u1/name=new',
          ]);
          expect(server.resources['u1/name'], 'new');
          outbox.dispose();
          async.flushMicrotasks();
        });
      });

      test('a pause while a send is out ends that item\'s run of failures '
          'too', () {
        fakeAsync((async) {
          final outbox = open(async);
          var slowSends = 0;
          outbox.register('slow', (item) async {
            if (++slowSends == 3) {
              await Future<void>.delayed(const Duration(minutes: 5));
            }
            return outboxResultFor(status: 503);
          });
          outbox.register(
            'other',
            (item) async => outboxResultFor(status: 401),
          );
          outbox.start('u1');
          late OutboxItem slow;
          outbox.enqueue('u1', kind: 'slow', payload: {}).then((i) => slow = i);
          async.elapse(const Duration(seconds: 10));
          expect(slowSends, 3);
          expect(read(async, slow.id)!.failures, 2);

          async.elapse(const Duration(minutes: 2));
          outbox.enqueue('u1', kind: 'other', payload: {});
          async.flushMicrotasks();
          expect(outbox.state.pause, OutboxPause.signIn);
          expect(read(async, slow.id)!.failures, 0);

          async.elapse(const Duration(minutes: 3));
          final landed = read(async, slow.id)!;
          expect(landed.status, OutboxStatus.pending);
          expect(landed.lastErrorCode, 'HTTP_503');
          expect(landed.failures, 1);
          outbox.dispose();
          async.flushMicrotasks();
        });
      });

      test('a send that never answers goes again only at the next '
          'launch', () {
        fakeAsync((async) {
          final outbox = open(async);
          var sends = 0;
          outbox.register('note', (item) {
            sends++;
            return Completer<OutboxResult>().future;
          });
          outbox.start('u1');
          late OutboxItem item;
          outbox.enqueue('u1', kind: 'note', payload: {}).then((i) => item = i);
          async.elapse(const Duration(days: 2));
          outbox.stop();
          outbox.start('u1');
          async.elapse(const Duration(hours: 1));
          expect(sends, 1);
          expect(read(async, item.id)!.status, OutboxStatus.sending);
          expect(outbox.state.pending, 1);
          outbox.dispose();

          final relaunched = open(async, seed: 8);
          relaunched.register('note', (item) async {
            sends++;
            return const OutboxResult.done();
          });
          relaunched.start('u1');
          async.flushMicrotasks();
          expect(sends, 2);
          expect(read(async, item.id)!.status, OutboxStatus.done);
          relaunched.dispose();
          async.flushMicrotasks();
        });
      });

      test('a clock set back while a retry waits does not stall it', () {
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
          setBack = const Duration(days: 1);
          async.elapse(const Duration(seconds: 30));
          expect(sent, ['A', 'A']);
          expect(outbox.state.pending, 0);
          outbox.dispose();
          async.flushMicrotasks();
        });
      });

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
    }, skip: backend.skip);
  }

  group('outbox across a relaunch', () {
    test('keeps an item\'s run of failures', () async {
      final clock = TestClock();
      final path = storeFile();
      final first = await openFileStore(clock, path: path);
      final before = Outbox(first, clock: clock.call, random: Random(3));
      before.register(
        'upload',
        (item) async => outboxResultFor(status: 0, networkError: true),
      );
      before.register('submission', (item) async => const OutboxResult.done());
      await before.start('u1');
      final upload = await before.enqueue('u1', kind: 'upload', payload: {});
      final submission = await before.enqueue(
        'u1',
        kind: 'submission',
        payload: {},
        dependsOn: upload.id,
      );
      await pumpEventQueue();
      await before.dispose();
      await first.close();

      clock.advance(const Duration(days: 2));
      final store = await openFileStore(clock, path: path);
      final after = Outbox(store, clock: clock.call, random: Random(4));
      addTearDown(after.dispose);
      final calls = <String>[];
      var uploads = 0;
      after.register('upload', (item) async {
        calls.add('upload');
        return ++uploads == 1
            ? outboxResultFor(status: 503)
            : const OutboxResult.done('up_1');
      });
      after.register('submission', (item) async {
        calls.add('submission');
        return const OutboxResult.done('s_1');
      });
      await after.start('u1');
      final waiting = (await store.outboxItem(upload.id))!;
      expect(calls, ['upload']);
      expect(waiting.status, OutboxStatus.pending);
      expect(waiting.failures, 2);
      expect(
        (await store.outboxItem(submission.id))!.status,
        OutboxStatus.pending,
      );

      clock.advance(outboxLongestWait);
      await after.kick();
      expect(calls, ['upload', 'upload', 'submission']);
    });

    test('sends again an item a killed app had on its way', () async {
      final clock = TestClock();
      final path = storeFile();
      final first = await openFileStore(clock, path: path);
      final before = Outbox(
        first,
        clock: clock.call,
        random: Random(3),
        sendTimeout: const Duration(milliseconds: 10),
      );
      final server = IdempotentServer();
      before.register('submission', (item) {
        server.post(item);
        return Completer<OutboxResult>().future;
      });
      await before.start('u1');
      final item = await before.enqueue(
        'u1',
        kind: 'submission',
        payload: {'resource': 'submit:c_1', 'value': 'entry'},
      );
      await before.kick();
      expect((await first.outboxItem(item.id))!.status, OutboxStatus.sending);
      await first.close();

      final store = await openFileStore(clock, path: path);
      final after = Outbox(store, clock: clock.call, random: Random(4));
      addTearDown(after.dispose);
      after.register('submission', (item) async => server.post(item));
      await after.start('u1');
      final done = (await store.outboxItem(item.id))!;
      expect(done.status, OutboxStatus.done);
      expect(done.attempts, 2);
      expect(server.requests, [item.id, item.id]);
      expect(server.applied, ['u1/submit:c_1=entry']);
    });
  }, skip: await sqliteMissing());
}

class _FakeTime extends TestClock {
  DateTime Function() read = DateTime.now;

  @override
  DateTime get now => read();
}
