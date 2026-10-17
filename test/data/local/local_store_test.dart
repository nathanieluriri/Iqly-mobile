import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/drafts_data.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/sqflite_local_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/local_stores.dart';

Map<String, Object?> _merge(
  Map<String, dynamic> older,
  Map<String, dynamic> newer,
) => {...older, ...newer};

const _photo = OutboxFile(
  localPath: '/data/outbox/photo.jpg',
  bytes: 48213,
  mime: 'image/jpeg',
);
const _brief = OutboxFile(
  localPath: '/data/outbox/brief.pdf',
  bytes: 1200,
  mime: 'application/pdf',
);

Future<void> main() async {
  for (final backend in await storeBackends()) {
    group('${backend.name} store', () {
      late TestClock clock;
      late LocalStore store;

      late DeletedFiles deleted;

      setUp(() async {
        clock = TestClock();
        deleted = DeletedFiles();
        store = await backend.open(clock, deleteFile: deleted.call);
      });

      Future<OutboxItem> item(String id) async => (await store.outboxItem(id))!;

      Future<List<String>> labels(String userId) async => [
        for (final item in await store.outbox(userId))
          item.payload['label'] as String,
      ];

      group('cache', () {
        test(
          'answers what was written, with its ETag and fetch time',
          () async {
            final page = {
              'items': [
                {'id': 'c_1', 'rewardPool': 5000000, 'minutes': null},
              ],
              'nextCursor': null,
            };
            await store.writeCache('u1', 'briefs', page, etag: 'W/"7"');
            final entry = await store.readCache('u1', 'briefs');
            expect(entry!.json, page);
            expect(entry.etag, 'W/"7"');
            expect(entry.fetchedAt, clock.now);
            expect(await store.readCache('u1', 'wallet'), isNull);
            expect(await store.readCache('u2', 'briefs'), isNull);

            await store.writeCache('u1', 'nothing', null);
            expect((await store.readCache('u1', 'nothing'))!.json, isNull);
          },
        );

        test('a new write replaces the entry', () async {
          await store.writeCache('u1', 'me', {'name': 'Ada'}, etag: 'a');
          clock.advance(const Duration(minutes: 5));
          await store.writeCache('u1', 'me', ['Ada', 'Obi']);
          final entry = await store.readCache('u1', 'me');
          expect(entry!.json, ['Ada', 'Obi']);
          expect(entry.etag, isNull);
          expect(entry.fetchedAt, clock.now);
        });

        test(
          'deletes one person\'s entries, or those under a prefix',
          () async {
            const keys = ['briefs/1', 'briefs/2', 'Briefs/3', 'briefs%', 'me'];
            for (final key in keys) {
              await store.writeCache('u1', key, key);
            }
            await store.writeCache('u2', 'briefs/1', 'theirs');
            Future<List<String>> kept(String userId) async => [
              for (final key in keys)
                if (await store.readCache(userId, key) != null) key,
            ];

            await store.deleteCache('u1', keyPrefix: 'briefs/');
            expect(await kept('u1'), ['Briefs/3', 'briefs%', 'me']);
            expect(await kept('u2'), ['briefs/1']);

            await store.deleteCache('u1');
            expect(await kept('u1'), isEmpty);
            expect(await kept('u2'), ['briefs/1']);
          },
        );
      });

      group('drafts', () {
        final edited = DateTime(2026, 10, 17, 8, 30, 15, 123, 456);

        test('come back with every field', () async {
          final draft = Draft(
            briefId: 'c_1',
            title: 'Sunday is data day',
            answer: 'Students plan the week on Sunday night.',
            answers: {
              'q1': ['weekly', 'monthly'],
              'q2': ['Typed answer'],
            },
            step: DraftSteps.questions,
            editedAt: edited,
          );
          await store.saveDraft('u1', draft);
          final saved = (await store.drafts('u1')).single;
          expect(saved.briefId, 'c_1');
          expect(saved.title, draft.title);
          expect(saved.answer, draft.answer);
          expect(saved.answers, draft.answers);
          expect(saved.step, DraftSteps.questions);
          expect(saved.editedAt, edited);
          expect(await store.drafts('u2'), isEmpty);
        });

        test('one per brief, newest edit first', () async {
          await store.saveDraft(
            'u1',
            Draft(briefId: 'c_1', title: 'First', editedAt: edited),
          );
          await store.saveDraft(
            'u1',
            Draft(
              briefId: 'c_2',
              title: 'Second',
              editedAt: edited.add(const Duration(hours: 1)),
            ),
          );
          await store.saveDraft(
            'u1',
            Draft(
              briefId: 'c_1',
              title: 'First, again',
              step: 3,
              editedAt: edited.add(const Duration(hours: 2)),
            ),
          );
          final drafts = await store.drafts('u1');
          expect([for (final d in drafts) d.title], ['First, again', 'Second']);
          expect(drafts.first.step, 3);
        });

        test('saving an empty draft removes it', () async {
          await store.saveDraft(
            'u1',
            Draft(briefId: 'c_1', answer: 'Something', editedAt: edited),
          );
          await store.saveDraft('u1', Draft(briefId: 'c_1', editedAt: edited));
          expect(await store.drafts('u1'), isEmpty);
        });

        test('deletes the briefs named, for that person only', () async {
          for (final user in ['u1', 'u2']) {
            for (final brief in ['c_1', 'c_2', 'c_3']) {
              await store.saveDraft(
                user,
                Draft(briefId: brief, title: brief, editedAt: edited),
              );
            }
          }
          await store.deleteDrafts('u1', ['c_1', 'c_3', 'c_9']);
          expect(
            [for (final d in await store.drafts('u1')) d.briefId],
            ['c_2'],
          );
          expect(await store.drafts('u2'), hasLength(3));
        });
      });

      group('outbox', () {
        test('queues a pending item, due now, with a UUID', () async {
          final payload = {
            'label': 'A',
            'title': 'Sunday is data day',
            'amount': 1250000,
            'ratio': 0.5,
            'agreed': true,
            'note': null,
            'answers': [
              'weekly',
              {'q2': 'Typed answer'},
            ],
          };
          final queued = await store.enqueue(
            'u1',
            kind: 'submission',
            payload: payload,
            files: const [_photo, _brief],
          );
          expect(
            queued.id,
            matches(
              RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
                r'[0-9a-f]{12}$',
              ),
            ),
          );
          final stored = await item(queued.id);
          expect(stored.userId, 'u1');
          expect(stored.kind, 'submission');
          expect(stored.payload, payload);
          expect(stored.status, OutboxStatus.pending);
          expect(stored.attempts, 0);
          expect(stored.nextAttemptAt, clock.now);
          expect(stored.createdAt, clock.now);
          expect(stored.updatedAt, clock.now);
          expect(stored.coalesceKey, isNull);
          expect(stored.dependsOn, isNull);
          expect(stored.retryAfter, isNull);
          expect(stored.failures, 0);
          expect(stored.failingSince, isNull);
          expect(stored.serverRef, isNull);
          expect(
            [for (final f in stored.files) f.localPath],
            [_photo.localPath, _brief.localPath],
          );
          expect(stored.files.first.bytes, 48213);
          expect(stored.files.first.mime, 'image/jpeg');

          final next = await store.enqueue('u1', kind: 'note', payload: {});
          expect(next.id, isNot(queued.id));
        });

        test('a write with a pending item\'s key replaces its payload in '
            'place', () async {
          final first = await store.enqueue(
            'u1',
            kind: 'brief.save',
            payload: {'label': 'save'},
            coalesceKey: 'saved:c_1',
          );
          await store.enqueue('u1', kind: 'note', payload: {'label': 'note'});
          clock.advance(const Duration(seconds: 3));
          final folded = await store.enqueue(
            'u1',
            kind: 'brief.unsave',
            payload: {'label': 'unsave'},
            coalesceKey: 'saved:c_1',
          );
          expect(folded.id, first.id);
          expect(folded.kind, 'brief.unsave');
          expect(folded.payload, {'label': 'unsave'});
          expect(folded.createdAt, first.createdAt);
          expect(folded.updatedAt, clock.now);
          expect(await labels('u1'), ['unsave', 'note']);
        });

        test('a merge function folds the payloads together', () async {
          final first = await store.enqueue(
            'u1',
            kind: 'profile',
            payload: {'label': 'profile', 'name': 'Ada'},
            coalesceKey: 'profile',
            merge: _merge,
          );
          final folded = await store.enqueue(
            'u1',
            kind: 'profile',
            payload: {'city': 'Yaba'},
            coalesceKey: 'profile',
            merge: _merge,
          );
          expect(folded.id, first.id);
          expect(folded.payload, {
            'label': 'profile',
            'name': 'Ada',
            'city': 'Yaba',
          });
          expect(await store.outbox('u1'), hasLength(1));
        });

        test('coalescing keeps to pending items of the same person', () async {
          final sending = await store.enqueue(
            'u1',
            kind: 'profile',
            payload: {'label': 'sending'},
            coalesceKey: 'profile',
          );
          await store.markSending(sending.id);
          final queued = await store.enqueue(
            'u1',
            kind: 'profile',
            payload: {'label': 'queued'},
            coalesceKey: 'profile',
          );
          expect(queued.id, isNot(sending.id));
          await store.markRetry(sending.id, at: clock.now);
          await store.enqueue(
            'u1',
            kind: 'profile',
            payload: {'label': 'latest'},
            coalesceKey: 'profile',
          );
          expect(await labels('u1'), ['sending', 'latest']);

          final refused = await store.enqueue(
            'u1',
            kind: 'prefs',
            payload: {'label': 'refused'},
            coalesceKey: 'prefs',
          );
          await store.markFailed(refused.id, code: 'VALIDATION_ERROR');
          await store.enqueue(
            'u1',
            kind: 'prefs',
            payload: {'label': 'prefs'},
            coalesceKey: 'prefs',
          );
          await store.enqueue(
            'u2',
            kind: 'profile',
            payload: {'label': 'theirs'},
            coalesceKey: 'profile',
          );
          expect(await labels('u1'), ['sending', 'latest', 'refused', 'prefs']);
          expect(await labels('u2'), ['theirs']);
        });

        test('a write folds only into an item naming the same dependency, '
            'none included', () async {
          final account = await store.enqueue(
            'u1',
            kind: 'bank',
            payload: {'label': 'bank'},
          );
          Future<OutboxItem> profile(String label, [String? dependsOn]) =>
              store.enqueue(
                'u1',
                kind: 'profile',
                payload: {'label': label},
                coalesceKey: 'profile',
                dependsOn: dependsOn,
              );

          final one = await profile('one');
          final two = await profile('two', account.id);
          final three = await profile('three');
          final four = await profile('four', account.id);
          final five = await profile('five', account.id);
          final ghost = await profile('ghost', 'gone');
          expect(two.id, isNot(one.id));
          expect(three.id, isNot(two.id));
          expect(three.dependsOn, isNull);
          expect(four.id, isNot(three.id));
          expect(five.id, four.id);
          expect(five.dependsOn, account.id);
          expect(ghost.id, isNot(four.id));
          expect(await labels('u1'), [
            'bank',
            'one',
            'two',
            'three',
            'five',
            'ghost',
          ]);
        });

        test('a fold\'s files replace the older ones entirely, none '
            'included', () async {
          final first = await store.enqueue(
            'u1',
            kind: 'avatar',
            payload: {},
            coalesceKey: 'avatar',
            files: const [_photo],
          );
          var folded = await store.enqueue(
            'u1',
            kind: 'avatar',
            payload: {},
            coalesceKey: 'avatar',
          );
          expect(folded.id, first.id);
          expect(folded.files, isEmpty);
          expect((await item(first.id)).files, isEmpty);

          folded = await store.enqueue(
            'u1',
            kind: 'avatar',
            payload: {},
            coalesceKey: 'avatar',
            files: const [_brief, _photo],
          );
          expect(folded.id, first.id);
          expect(
            [for (final f in (await item(first.id)).files) f.localPath],
            [_brief.localPath, _photo.localPath],
          );
        });

        test('a write folds only into an item never sent', () async {
          Future<OutboxItem> write(String key, String label) => store.enqueue(
            'u1',
            kind: 'proof',
            payload: {'label': label},
            coalesceKey: key,
          );

          final onItsWay = await write('proof', 'blurry');
          await store.markSending(onItsWay.id);
          final behind = await write('proof', 'sharp');
          expect(behind.id, isNot(onItsWay.id));
          expect((await write('proof', 'sharper')).id, behind.id);

          final retried = await write('bio', 'one');
          await store.markSending(retried.id);
          await store.markRetry(retried.id, at: clock.now);
          expect((await write('bio', 'two')).id, isNot(retried.id));

          final cutOff = await write('avatar', 'x');
          await store.markSending(cutOff.id);
          await store.resetSending();
          expect((await write('avatar', 'y')).id, isNot(cutOff.id));

          expect(await labels('u1'), [
            'blurry',
            'sharper',
            'one',
            'two',
            'x',
            'y',
          ]);
        });

        test('an item due further ahead than any wait set for it is due '
            'now, as after the clock was set back', () async {
          Future<void> waiting(
            String label,
            Duration wait, [
            Duration? retryAfter,
          ]) async {
            final queued = await store.enqueue(
              'u1',
              kind: 'note',
              payload: {'label': label},
            );
            await store.markRetry(
              queued.id,
              at: clock.now.add(wait),
              retryAfter: retryAfter,
            );
          }

          await waiting('backoff', const Duration(minutes: 10));
          await waiting('longest', outboxLongestWait);
          await waiting('skewed', const Duration(minutes: 16));
          await waiting(
            'asked',
            const Duration(minutes: 50),
            const Duration(hours: 1),
          );
          await waiting(
            'askedSkewed',
            const Duration(minutes: 61),
            const Duration(hours: 1),
          );
          final due = await store.dueOutbox('u1', clock.now);
          expect(
            [for (final i in due) i.payload['label']],
            ['skewed', 'askedSkewed'],
          );
          for (final item in due) {
            expect(item.dueAt(clock.now), clock.now);
          }
        });

        test('due items are the person\'s pending ones whose time has '
            'come, oldest first', () async {
          Future<String> add(String label, [String user = 'u1']) async =>
              (await store.enqueue(
                user,
                kind: 'note',
                payload: {'label': label},
              )).id;
          final a = await add('A');
          final later = await add('later');
          final failed = await add('failed');
          final sending = await add('sending');
          final done = await add('done');
          final b = await add('B');
          await add('theirs', 'u2');
          await store.markRetry(
            later,
            at: clock.now.add(const Duration(minutes: 1)),
          );
          await store.markFailed(failed, code: 'VALIDATION_ERROR');
          await store.markSending(sending);
          await store.markSending(done);
          await store.markDone(done);

          Future<List<String>> due(DateTime now) async => [
            for (final i in await store.dueOutbox('u1', now)) i.id,
          ];
          expect(await due(clock.now), [a, b]);
          expect(await due(clock.now.add(const Duration(minutes: 1))), [
            a,
            later,
            b,
          ]);
          expect(await labels('u1'), ['A', 'later', 'failed', 'sending', 'B']);
        });

        test('sending claims a pending item and counts the attempt', () async {
          final queued = await store.enqueue('u1', kind: 'note', payload: {});
          clock.advance(const Duration(seconds: 1));
          final claimed = await store.markSending(queued.id);
          expect(claimed!.status, OutboxStatus.sending);
          expect(claimed.attempts, 1);
          expect(claimed.updatedAt, clock.now);
          expect(await store.markSending(queued.id), isNull);
          expect(await store.markSending('nope'), isNull);
        });

        test('done keeps the server\'s id and leaves the queue', () async {
          final queued = await store.enqueue('u1', kind: 'note', payload: {});
          await store.markSending(queued.id);
          await store.markDone(queued.id, serverRef: 's_1');
          final done = await item(queued.id);
          expect(done.status, OutboxStatus.done);
          expect(done.serverRef, 's_1');
          expect(await store.outbox('u1'), isEmpty);
        });

        test('retry and failure keep why', () async {
          final queued = await store.enqueue('u1', kind: 'note', payload: {});
          await store.markSending(queued.id);
          final at = clock.now.add(const Duration(seconds: 30));
          final since = clock.now.subtract(const Duration(hours: 2));
          await store.markRetry(
            queued.id,
            at: at,
            code: 'RATE_LIMITED',
            message: 'Slow down',
            retryAfter: const Duration(seconds: 30),
            failures: 3,
            failingSince: since,
          );
          var stored = await item(queued.id);
          expect(stored.status, OutboxStatus.pending);
          expect(stored.nextAttemptAt, at);
          expect(stored.lastErrorCode, 'RATE_LIMITED');
          expect(stored.lastErrorMessage, 'Slow down');
          expect(stored.retryAfter, const Duration(seconds: 30));
          expect(stored.failures, 3);
          expect(stored.failingSince, since);

          await store.markSending(queued.id);
          await store.markRetry(queued.id, at: at, code: 'UNAUTHORIZED');
          stored = await item(queued.id);
          expect(stored.retryAfter, isNull);
          expect(stored.failures, 0);
          expect(stored.failingSince, isNull);

          await store.markFailed(
            queued.id,
            code: 'UNDER_AGE',
            message: 'You need to be 18',
          );
          stored = await item(queued.id);
          expect(stored.status, OutboxStatus.failed);
          expect(stored.lastErrorCode, 'UNDER_AGE');
          expect(stored.lastErrorMessage, 'You need to be 18');
          expect(stored.attempts, 2);
        });

        test('a pause ends the run of failures of the person\'s unsent '
            'items', () async {
          final since = clock.now;
          Future<OutboxItem> failing(String user) async {
            final queued = await store.enqueue(user, kind: 'note', payload: {});
            await store.markSending(queued.id);
            await store.markRetry(
              queued.id,
              at: clock.now,
              failures: 7,
              failingSince: since,
            );
            return queued;
          }

          final waiting = await failing('u1');
          final sending = await failing('u1');
          await store.markSending(sending.id);
          final refused = await failing('u1');
          await store.markFailed(refused.id, code: 'OUTBOX_EXPIRED');
          final theirs = await failing('u2');
          await store.resetFailures('u1');
          for (final ended in [waiting, sending]) {
            final stored = await item(ended.id);
            expect(stored.failures, 0);
            expect(stored.failingSince, isNull);
          }
          for (final kept in [refused, theirs]) {
            final stored = await item(kept.id);
            expect(stored.failures, 7);
            expect(stored.failingSince, since);
          }
          expect((await item(sending.id)).status, OutboxStatus.sending);
        });

        test('requeue puts a failed item back, due now, its run of failures '
            'ended', () async {
          final queued = await store.enqueue(
            'u1',
            kind: 'note',
            payload: {},
            files: const [_photo],
          );
          await store.markSending(queued.id);
          await store.markRetry(
            queued.id,
            at: clock.now.add(const Duration(minutes: 9)),
            code: 'HTTP_503',
            retryAfter: const Duration(minutes: 9),
            failures: 199,
            failingSince: clock.now,
          );
          await store.markSending(queued.id);
          await store.markFailed(queued.id, code: 'OUTBOX_EXPIRED');
          clock.advance(const Duration(days: 3));
          expect(await store.requeue(queued.id), isTrue);
          final back = await item(queued.id);
          expect(back.status, OutboxStatus.pending);
          expect(back.nextAttemptAt, clock.now);
          expect(back.updatedAt, clock.now);
          expect(back.retryAfter, isNull);
          expect(back.failures, 0);
          expect(back.failingSince, isNull);
          expect(back.attempts, 2);
          expect(back.lastErrorCode, 'OUTBOX_EXPIRED');
          expect(back.files.single.localPath, _photo.localPath);
          expect(
            [for (final i in await store.dueOutbox('u1', clock.now)) i.id],
            [queued.id],
          );
        });

        test('requeue leaves an item that is not failed', () async {
          final pending = await store.enqueue('u1', kind: 'note', payload: {});
          final sending = await store.enqueue('u1', kind: 'note', payload: {});
          await store.markSending(sending.id);
          final done = await store.enqueue('u1', kind: 'note', payload: {});
          await store.markSending(done.id);
          await store.markDone(done.id);
          clock.advance(const Duration(minutes: 1));
          for (final id in [pending.id, sending.id, done.id, 'nope']) {
            expect(await store.requeue(id), isFalse);
          }
          expect((await item(pending.id)).updatedAt, isNot(clock.now));
          expect((await item(sending.id)).status, OutboxStatus.sending);
          expect((await item(done.id)).status, OutboxStatus.done);
        });

        test('discard removes a pending or failed item, and fails what '
            'depends on it', () async {
          final upload = await store.enqueue(
            'u1',
            kind: 'upload',
            payload: {'label': 'upload'},
            files: const [_photo],
          );
          final waiting = await store.enqueue(
            'u1',
            kind: 'submission',
            payload: {'label': 'waiting'},
            dependsOn: upload.id,
          );
          final refused = await store.enqueue(
            'u1',
            kind: 'submission',
            payload: {'label': 'refused'},
            dependsOn: upload.id,
          );
          await store.markFailed(refused.id, code: 'FILE_TOO_LARGE');
          final behind = await store.enqueue(
            'u1',
            kind: 'note',
            payload: {'label': 'behind'},
            dependsOn: waiting.id,
          );
          final other = await store.enqueue(
            'u1',
            kind: 'note',
            payload: {'label': 'other'},
          );
          clock.advance(const Duration(minutes: 1));

          expect(
            await store.discard(upload.id, dependantsCode: 'GONE'),
            isTrue,
          );
          expect(await store.outboxItem(upload.id), isNull);
          for (final dependant in [waiting, refused]) {
            final failed = await item(dependant.id);
            expect(failed.status, OutboxStatus.failed);
            expect(failed.lastErrorCode, 'GONE');
            expect(failed.lastErrorMessage, isNull);
            expect(failed.updatedAt, clock.now);
          }
          expect((await item(behind.id)).status, OutboxStatus.pending);
          expect((await item(other.id)).status, OutboxStatus.pending);
          expect(await labels('u1'), ['waiting', 'refused', 'behind', 'other']);

          expect(
            await store.discard(refused.id, dependantsCode: 'GONE'),
            isTrue,
          );
          expect(
            await store.discard(upload.id, dependantsCode: 'GONE'),
            isFalse,
          );
          expect(await labels('u1'), ['waiting', 'behind', 'other']);
        });

        test('a newer write with a key supersedes the person\'s failed '
            'items with it, keeping their files', () async {
          Future<OutboxItem> failed(
            String user,
            String label, {
            String? key,
            List<OutboxFile> files = const [],
          }) async {
            final queued = await store.enqueue(
              user,
              kind: 'prefs',
              payload: {'label': label},
              coalesceKey: key,
              files: files,
            );
            await store.markSending(queued.id);
            await store.markFailed(
              queued.id,
              code: 'VALIDATION_ERROR',
              message: 'Polls are off',
            );
            return queued;
          }

          final refused = await failed('u1', 'refused', key: 'prefs');
          final withFile = await failed(
            'u1',
            'with file',
            key: 'prefs',
            files: const [_photo],
          );
          final keyless = await failed('u1', 'keyless');
          final otherKey = await failed('u1', 'other key', key: 'profile');
          final theirs = await failed('u2', 'theirs', key: 'prefs');
          final done = await store.enqueue(
            'u1',
            kind: 'prefs',
            payload: {'label': 'done'},
            coalesceKey: 'prefs',
          );
          await store.markSending(done.id);
          await store.markDone(done.id);
          clock.advance(const Duration(minutes: 1));

          await store.enqueue(
            'u1',
            kind: 'prefs',
            payload: {'label': 'newer'},
            coalesceKey: 'prefs',
          );
          await store.enqueue('u1', kind: 'prefs', payload: {'label': 'x'});
          for (final old in [refused, withFile]) {
            final superseded = await item(old.id);
            expect(superseded.status, OutboxStatus.failed);
            expect(superseded.lastErrorCode, outboxSupersededCode);
            expect(superseded.lastErrorMessage, 'Polls are off');
            expect(superseded.updatedAt, clock.now);
          }
          expect(
            (await item(withFile.id)).files.single.localPath,
            _photo.localPath,
          );
          expect(deleted.paths, isEmpty);
          for (final kept in [keyless, otherKey, theirs]) {
            expect((await item(kept.id)).lastErrorCode, 'VALIDATION_ERROR');
          }
          expect((await item(done.id)).status, OutboxStatus.done);
          expect(outboxSupersededCode, 'SUPERSEDED');
        });

        test('an item failing while a newer item of its person has its key '
            'fails as superseded, keeping its message and files', () async {
          Future<OutboxItem> write(
            String label, {
            String user = 'u1',
            String? key = 'prefs',
            List<OutboxFile> files = const [],
          }) => store.enqueue(
            user,
            kind: 'prefs',
            payload: {'label': label},
            coalesceKey: key,
            files: files,
          );

          final older = await write('older', files: const [_photo]);
          await store.markSending(older.id);
          await store.markRetry(older.id, at: clock.now);
          final keyless = await write('keyless', key: null);
          final otherKey = await write('other key', key: 'profile');
          final first = await write('first', user: 'u2');
          final newer = await write('newer');
          await write('keyless newer', key: null);
          await write('theirs newer', user: 'u3');
          await store.markSending(newer.id);
          await store.markDone(newer.id);
          clock.advance(const Duration(minutes: 1));

          for (final item in [older, keyless, otherKey, first, newer]) {
            await store.markFailed(
              item.id,
              code: 'VALIDATION_ERROR',
              message: 'Polls are off',
            );
          }
          final superseded = await item(older.id);
          expect(superseded.status, OutboxStatus.failed);
          expect(superseded.lastErrorCode, outboxSupersededCode);
          expect(superseded.lastErrorMessage, 'Polls are off');
          expect(superseded.updatedAt, clock.now);
          expect(superseded.files.single.localPath, _photo.localPath);
          expect(deleted.paths, isEmpty);
          for (final kept in [keyless, otherKey, first, newer]) {
            final failed = await item(kept.id);
            expect(failed.status, OutboxStatus.failed);
            expect(failed.lastErrorCode, 'VALIDATION_ERROR');
          }
        });

        test('discard fails a dependant as superseded when a newer item has '
            'its key', () async {
          final upload = await store.enqueue('u1', kind: 'upload', payload: {});
          final photo = await store.enqueue(
            'u1',
            kind: 'avatar',
            payload: {},
            coalesceKey: 'avatar',
            dependsOn: upload.id,
          );
          final note = await store.enqueue(
            'u1',
            kind: 'note',
            payload: {},
            dependsOn: upload.id,
          );
          await store.enqueue(
            'u1',
            kind: 'avatar',
            payload: {},
            coalesceKey: 'avatar',
          );
          expect(
            await store.discard(upload.id, dependantsCode: 'GONE'),
            isTrue,
          );
          expect((await item(photo.id)).lastErrorCode, outboxSupersededCode);
          expect((await item(note.id)).lastErrorCode, 'GONE');
        });

        test('resetBackoff puts the person\'s pending items due now, keeping '
            'their run of failures', () async {
          final since = clock.now;
          Future<OutboxItem> waiting(String user) async {
            final queued = await store.enqueue(user, kind: 'note', payload: {});
            await store.markSending(queued.id);
            await store.markRetry(
              queued.id,
              at: clock.now.add(const Duration(minutes: 14)),
              code: 'HTTP_503',
              retryAfter: const Duration(minutes: 14),
              failures: 7,
              failingSince: since,
            );
            return queued;
          }

          final mine = await waiting('u1');
          final theirs = await waiting('u2');
          final sending = await waiting('u1');
          await store.markSending(sending.id);
          clock.advance(const Duration(minutes: 1));
          await store.resetBackoff('u1');
          final due = await item(mine.id);
          expect(due.nextAttemptAt, clock.now);
          expect(due.retryAfter, isNull);
          expect(due.failures, 7);
          expect(due.failingSince, since);
          expect(due.lastErrorCode, 'HTTP_503');
          expect(
            [for (final i in await store.dueOutbox('u1', clock.now)) i.id],
            [mine.id],
          );
          expect(
            (await item(theirs.id)).nextAttemptAt,
            since.add(const Duration(minutes: 14)),
          );
          expect((await item(sending.id)).status, OutboxStatus.sending);
        });

        test('resetFailures puts the person\'s pending items due now as it '
            'ends their run of failures', () async {
          final queued = await store.enqueue('u1', kind: 'note', payload: {});
          await store.markSending(queued.id);
          await store.markRetry(
            queued.id,
            at: clock.now.add(const Duration(minutes: 9)),
            failures: 30,
            failingSince: clock.now,
          );
          clock.advance(const Duration(minutes: 1));
          await store.resetFailures('u1');
          final reset = await item(queued.id);
          expect(reset.nextAttemptAt, clock.now);
          expect(reset.failures, 0);
          expect(reset.failingSince, isNull);
        });

        test('a write folding into a waiting item supersedes the failed ones '
            'with its key too', () async {
          final waiting = await store.enqueue(
            'u1',
            kind: 'prefs',
            payload: {'label': 'waiting'},
            coalesceKey: 'prefs',
          );
          final refused = await store.enqueue(
            'u1',
            kind: 'prefs',
            payload: {'label': 'refused'},
            coalesceKey: 'prefs',
            dependsOn: 'bank',
          );
          await store.markFailed(refused.id, code: 'VALIDATION_ERROR');
          final folded = await store.enqueue(
            'u1',
            kind: 'prefs',
            payload: {'label': 'newer'},
            coalesceKey: 'prefs',
          );
          expect(folded.id, waiting.id);
          expect((await item(refused.id)).lastErrorCode, outboxSupersededCode);
        });

        test('discard leaves an item on its way or done', () async {
          final sending = await store.enqueue('u1', kind: 'note', payload: {});
          await store.markSending(sending.id);
          final done = await store.enqueue('u1', kind: 'note', payload: {});
          await store.markSending(done.id);
          await store.markDone(done.id);
          final dependant = await store.enqueue(
            'u1',
            kind: 'note',
            payload: {},
            dependsOn: sending.id,
          );
          for (final id in [sending.id, done.id]) {
            expect(await store.discard(id, dependantsCode: 'GONE'), isFalse);
          }
          expect((await item(sending.id)).status, OutboxStatus.sending);
          expect((await item(done.id)).status, OutboxStatus.done);
          expect((await item(dependant.id)).status, OutboxStatus.pending);
        });

        test('sending items go back to pending after a restart', () async {
          final one = await store.enqueue('u1', kind: 'note', payload: {});
          final two = await store.enqueue('u2', kind: 'note', payload: {});
          final waiting = await store.enqueue('u1', kind: 'note', payload: {});
          await store.markSending(one.id);
          await store.markSending(two.id);
          expect(await store.resetSending(), 2);
          for (final id in [one.id, two.id, waiting.id]) {
            expect((await item(id)).status, OutboxStatus.pending);
          }
          expect((await item(one.id)).attempts, 1);
        });

        test(
          'old done items go, unless an unsent item depends on them',
          () async {
            Future<String> doneItem() async {
              final queued = await store.enqueue(
                'u1',
                kind: 'note',
                payload: {},
              );
              await store.markSending(queued.id);
              await store.markDone(queued.id);
              return queued.id;
            }

            final old = await doneItem();
            final needed = await doneItem();
            await store.enqueue(
              'u1',
              kind: 'note',
              payload: {},
              dependsOn: needed,
            );
            clock.advance(const Duration(days: 2));
            final recent = await doneItem();
            expect(
              await store.pruneDone(
                clock.now.subtract(const Duration(days: 1)),
              ),
              1,
            );
            expect(await store.outboxItem(old), isNull);
            expect(await store.outboxItem(needed), isNotNull);
            expect(await store.outboxItem(recent), isNotNull);
          },
        );

        test('deletes one person\'s outbox', () async {
          final mine = await store.enqueue(
            'u1',
            kind: 'note',
            payload: {},
            files: const [_photo],
          );
          await store.enqueue('u2', kind: 'note', payload: {'label': 'B'});
          await store.deleteOutbox('u1');
          expect(await store.outboxItem(mine.id), isNull);
          expect(await labels('u2'), ['B']);
        });
      });

      group('queued files', () {
        Future<OutboxItem> queue(
          String user,
          List<OutboxFile> files, {
          String? key,
        }) => store.enqueue(
          user,
          kind: 'submission',
          payload: {},
          coalesceKey: key,
          files: files,
        );

        test('leave the phone once their item is done', () async {
          final queued = await queue('u1', const [_photo, _brief]);
          await store.markSending(queued.id);
          await store.markRetry(queued.id, at: clock.now);
          await store.markSending(queued.id);
          expect(deleted.paths, isEmpty);
          await store.markDone(queued.id);
          expect(deleted.paths, [_photo.localPath, _brief.localPath]);
          expect((await item(queued.id)).files, isEmpty);
        });

        test('replaced by a fold leave, unless the new write names them '
            'again', () async {
          final first = await queue('u1', const [_photo, _brief], key: 'k');
          await queue('u1', const [_photo], key: 'k');
          expect(deleted.paths, [_brief.localPath]);
          await queue('u1', const [], key: 'k');
          expect(deleted.paths, [_brief.localPath, _photo.localPath]);
          expect((await item(first.id)).files, isEmpty);
        });

        test('shared by two items stay until neither needs them', () async {
          final one = await queue('u1', const [_photo]);
          final two = await queue('u1', const [_photo, _brief]);
          await store.markSending(one.id);
          await store.markDone(one.id);
          expect(deleted.paths, isEmpty);
          await store.markSending(two.id);
          await store.markDone(two.id);
          expect(deleted.paths, [_photo.localPath, _brief.localPath]);
        });

        test('stay while their item is failed, and leave when it is '
            'discarded', () async {
          final queued = await queue('u1', const [_photo]);
          await store.markSending(queued.id);
          await store.markFailed(queued.id, code: 'FILE_TOO_LARGE');
          expect(deleted.paths, isEmpty);
          await store.discard(queued.id, dependantsCode: 'GONE');
          expect(deleted.paths, [_photo.localPath]);
        });

        test('leave with the person\'s outbox and when they are wiped, and '
            'no one else\'s do', () async {
          const theirs = OutboxFile(
            localPath: '/data/outbox/theirs.jpg',
            bytes: 1,
            mime: 'image/jpeg',
          );
          await queue('u1', const [_photo]);
          await queue('u1', const [_brief]);
          await queue('u2', const [theirs]);
          await store.deleteOutbox('u1');
          expect(deleted.paths, [_photo.localPath, _brief.localPath]);
          await queue('u1', const [_photo]);
          await store.wipeUser('u1');
          expect(deleted.paths, [
            _photo.localPath,
            _brief.localPath,
            _photo.localPath,
          ]);
          expect(
            (await store.outbox('u2')).single.files.single.localPath,
            theirs.localPath,
          );
        });

        test('are deleted from disk, and one already gone is no '
            'error', () async {
          final dir = Directory.systemTemp.createTempSync('iqly_outbox_');
          addTearDown(() => dir.delete(recursive: true));
          final disk = await backend.open(clock, deleteFile: deleteQueuedFile);
          OutboxFile file(String name) {
            final path = '${dir.path}${Platform.pathSeparator}$name';
            File(path).writeAsBytesSync([1, 2, 3]);
            return OutboxFile(localPath: path, bytes: 3, mime: 'image/jpeg');
          }

          final kept = file('kept.jpg');
          final sent = file('sent.jpg');
          final gone = file('gone.jpg');
          final queued = await disk.enqueue(
            'u1',
            kind: 'submission',
            payload: {},
            files: [sent, gone],
          );
          await disk.enqueue(
            'u1',
            kind: 'submission',
            payload: {},
            files: [kept],
          );
          File(gone.localPath).deleteSync();
          await disk.markSending(queued.id);
          await disk.markDone(queued.id);
          expect(File(sent.localPath).existsSync(), isFalse);
          expect(File(kept.localPath).existsSync(), isTrue);
        });
      });

      test('wiping a person removes their cache, drafts and outbox', () async {
        for (final user in ['u1', 'u2']) {
          await store.writeCache(user, 'me', {'id': user});
          await store.saveDraft(
            user,
            Draft(briefId: 'c_1', title: 'Hi', editedAt: clock.now),
          );
          final sent = await store.enqueue(
            user,
            kind: 'note',
            payload: {'label': user},
          );
          await store.markSending(sent.id);
          await store.markDone(sent.id);
          await store.enqueue(user, kind: 'note', payload: {'label': user});
        }
        await store.wipeUser('u1');
        expect(await store.readCache('u1', 'me'), isNull);
        expect(await store.drafts('u1'), isEmpty);
        expect(await store.outbox('u1'), isEmpty);
        expect((await store.readCache('u2', 'me'))!.json, {'id': 'u2'});
        expect(await store.drafts('u2'), hasLength(1));
        expect(await labels('u2'), ['u2']);
      });
    }, skip: backend.skip);
  }

  group('sqflite store file', () {
    test('keeps everything across a restart', () async {
      final clock = TestClock();
      final path = storeFile();
      var store = await openFileStore(clock, path: path);
      await store.writeCache('u1', 'me', {'name': 'Ada'}, etag: 'e1');
      await store.saveDraft(
        'u1',
        Draft(briefId: 'c_1', title: 'Hi', step: 2, editedAt: clock.now),
      );
      final queued = await store.enqueue(
        'u1',
        kind: 'submission',
        payload: {'title': 'Hi'},
        files: const [_photo],
      );
      await store.markSending(queued.id);
      await store.close();

      store = await openFileStore(clock, path: path);
      expect((await store.readCache('u1', 'me'))!.etag, 'e1');
      expect((await store.drafts('u1')).single.step, 2);
      expect(await store.resetSending(), 1);
      final restored = (await store.outboxItem(queued.id))!;
      expect(restored.status, OutboxStatus.pending);
      expect(restored.attempts, 1);
      expect(restored.files.single.localPath, _photo.localPath);
    });

    test('is at schema version 1', () async {
      final path = storeFile();
      await (await openFileStore(TestClock(), path: path)).close();
      final db = await databaseFactoryFfiNoIsolate.openDatabase(path);
      addTearDown(db.close);
      expect(await db.getVersion(), SqfliteLocalStore.schemaVersion);
      expect(SqfliteLocalStore.schemaVersion, 1);
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
      );
      expect(
        [for (final t in tables) t['name']],
        ['cache', 'drafts', 'outbox', 'outbox_files'],
      );
    });
  }, skip: await sqliteMissing());
}
