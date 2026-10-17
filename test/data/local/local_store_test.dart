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

      setUp(() async {
        clock = TestClock();
        store = await backend.open(clock);
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

        test(
          'a write naming another dependency queues behind instead',
          () async {
            final account = await store.enqueue(
              'u1',
              kind: 'bank',
              payload: {'label': 'bank'},
            );
            await store.enqueue(
              'u1',
              kind: 'profile',
              payload: {'label': 'one'},
              coalesceKey: 'profile',
            );
            final behind = await store.enqueue(
              'u1',
              kind: 'profile',
              payload: {'label': 'two'},
              coalesceKey: 'profile',
              dependsOn: account.id,
            );
            final folded = await store.enqueue(
              'u1',
              kind: 'profile',
              payload: {'label': 'three'},
              coalesceKey: 'profile',
            );
            expect(folded.id, behind.id);
            expect(folded.dependsOn, account.id);
            expect(await labels('u1'), ['bank', 'one', 'three']);
          },
        );

        test('new files replace a coalesced item\'s files', () async {
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
          expect(
            [for (final f in folded.files) f.localPath],
            [_photo.localPath],
          );
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
            failingSince: since,
          );
          var stored = await item(queued.id);
          expect(stored.status, OutboxStatus.pending);
          expect(stored.nextAttemptAt, at);
          expect(stored.lastErrorCode, 'RATE_LIMITED');
          expect(stored.lastErrorMessage, 'Slow down');
          expect(stored.retryAfter, const Duration(seconds: 30));
          expect(stored.failingSince, since);

          await store.markSending(queued.id);
          await store.markRetry(queued.id, at: at, code: 'UNAUTHORIZED');
          stored = await item(queued.id);
          expect(stored.retryAfter, isNull);
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

        test(
          'the give-up clock stops for the person\'s unsent items',
          () async {
            final since = clock.now;
            Future<OutboxItem> failing(String user) async {
              final queued = await store.enqueue(
                user,
                kind: 'note',
                payload: {},
              );
              await store.markSending(queued.id);
              await store.markRetry(
                queued.id,
                at: clock.now,
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
            await store.resetFailingSince('u1');
            expect((await item(waiting.id)).failingSince, isNull);
            expect((await item(sending.id)).failingSince, isNull);
            expect((await item(refused.id)).failingSince, since);
            expect((await item(theirs.id)).failingSince, since);
          },
        );

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
