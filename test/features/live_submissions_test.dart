import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/drafts_data.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/submit_data.dart';
import 'package:iqly_mobile/data/submit_service.dart';
import 'package:iqly_mobile/features/drafts/drafts_state.dart';
import 'package:iqly_mobile/features/submissions/submissions_state.dart';
import 'package:iqly_mobile/features/submit/submit_state.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/surfaces/surfaces.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/live/live_data_fixtures.dart';
import '../golden/screens/app_harness.dart';

final _now = DateTime(2026, 10, 17, 10);

/// One live brief in the feed; the person's entries answer two briefs that
/// have closed and left it.
FakeApi _liveEntries() {
  final api = FakeApi();
  api.data('GET', '/challenges/browse', {
    'items': [challengeJson()],
    'total': 1,
    'pageCount': 1,
    'page': 1,
    'perPage': 60,
  });
  api.data(
    'GET',
    '/submissions/mine',
    page([
      submissionJson({
        'id': 's_2',
        'challengeId': 'c_8',
        'title': 'Make the savings goal visible',
        'result': 'under_review',
        'createdAt': '2026-10-16T10:00:00.000Z',
        'award': null,
        'brief': {
          'id': 'c_8',
          'slug': null,
          'title': 'Why do people stop saving?',
          'businessName': null,
          'logoUrl': null,
          'coverUrl': null,
          'deadline': '2026-10-15T17:00:00.000Z',
          'rewardPool': 10000000,
          'status': 'closed',
        },
      }),
      submissionJson(),
    ]),
  );
  return api;
}

Future<ProviderContainer> _container(FakeApi api, {Backend? mode}) async {
  SharedPreferences.setMockInitialValues({'session.userId': 'u_1'});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => _now),
      localStoreProvider.overrideWithValue(MemoryLocalStore(clock: () => _now)),
      ...liveOverrides(api.api(), mode: mode),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('My submissions, live', () {
    test('entries on closed briefs carry their brief and award', () async {
      final c = await _container(_liveEntries());
      final mine = await c.read(mySubmissionsProvider.future);
      expect([for (final i in mine.items) i.id], ['s_2', 's_1']);
      final [review, winner] = mine.items;
      expect(review.brief!.title, 'Why do people stop saving?');
      expect(review.brief!.isLive, isFalse);
      expect(review.briefLine, 'Why do people stop saving?');
      expect(winner.status, SubmissionStatus.winner);
      expect(winner.briefLine, 'Orchid Foods · Why do people stop saving?');
      expect(winner.awardKobo, 1250000);
      expect(
        winner.awardedAt!.isAtSameMomentAs(DateTime.utc(2026, 10, 2, 10)),
        isTrue,
      );
      expect(mine.wonKobo, 1250000);
      final live = await c.read(repositoryProvider).briefs();
      expect(
        live.map((b) => b.id),
        isNot(contains('c_9')),
        reason: 'the brief left the live feed',
      );
    });

    testWidgets('a card shows an entry on a brief that has closed', (
      tester,
    ) async {
      final api = _liveEntries();
      await pumpApp(
        tester,
        Routes.submissions,
        clock: () => _now,
        repository: LiveRepository(
          api: api.api(),
          store: MemoryLocalStore(clock: () => _now),
          mode: allLive,
          demo: DemoRepository(DemoData(now: _now)),
          userId: 'u_1',
          clock: () => _now,
        ),
        overrides: liveOverrides(api.api()),
      );
      expect(find.text('Make the savings goal visible'), findsOneWidget);
      expect(find.text('Why do people stop saving?'), findsOneWidget);
      expect(find.text('Closed'), findsOneWidget);

      await tester.tap(find.text('Winners'));
      await tester.pumpAndSettle();
      expect(find.text('Sunday is data day'), findsOneWidget);
      expect(
        find.text('Orchid Foods · Why do people stop saving?'),
        findsOneWidget,
      );
      expect(find.text('Won ₦12.5k'), findsOneWidget);
    });

    test('preview joins its briefs and ledger as before', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final data = DemoData();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          repositoryProvider.overrideWithValue(DemoRepository(data)),
        ],
      );
      addTearDown(c.dispose);
      final mine = await c.read(mySubmissionsProvider.future);
      final winner = mine.items.firstWhere(
        (i) => i.status == SubmissionStatus.winner,
      );
      expect(
        winner.brief,
        same(data.briefs.firstWhere((b) => b.id == winner.submission.briefId)),
      );
      expect(winner.awardKobo, isNotNull);
    });
  });

  group('submit, live', () {
    test('the files show going up with the send, and come back on a '
        'failure', () async {
      final api = FakeApi();
      api.data('GET', '/challenges/c_1', challengeJson());
      api.data('GET', '/submissions/mine/by-challenge/c_1', null);
      final upload = Completer<void>();
      final seen = <String>[];
      api.on('POST', '/submissions/challenges/c_1', (_) {
        upload.complete();
        return refused(503, 'INFRASTRUCTURE_ERROR');
      });
      final c = await _container(api);
      await c.read(draftsProvider.future);
      final opening = c.listen(submitOpeningProvider('c_1'), (_, _) {});
      addTearDown(opening.close);
      await c.read(submitOpeningProvider('c_1').future);
      final sub = c.listen(submitFlowProvider('c_1'), (_, next) {
        for (final a in next.files) {
          seen.add('${a.status.name} ${(a.progress * 100).round()}');
        }
      });
      addTearDown(sub.close);
      final flow = c.read(submitFlowProvider('c_1').notifier);
      flow
        ..setTitle('Sunday is data day')
        ..setAnswer('Give a bonus bundle on Sundays.')
        ..next()
        ..pick(
          const SurveyQuestion(
            id: 'q_lang',
            text: '',
            options: ['English', 'Pidgin'],
          ),
          'Pidgin',
        )
        ..pick(
          const SurveyQuestion(
            id: 'q_where',
            text: '',
            options: ['USSD'],
            multi: true,
          ),
          'USSD',
        )
        ..type(
          const SurveyQuestion(id: 'q_why', text: ''),
          'It is the day people top up.',
        );
      flow.addFiles([
        AttachmentFile(
          name: 'poster.png',
          bytes: 3,
          read: () async => [1, 2, 3],
        ),
      ]);
      await pumpEventQueue();
      expect(
        c.read(submitFlowProvider('c_1')).files.single.status,
        AttachmentStatus.done,
      );

      final form = c.read(submitOpeningProvider('c_1')).value!.form!;
      final result = await flow.send(form);
      await upload.future;
      expect(result!.failure, SubmitFailure.unknown);
      expect(seen, contains('uploading 0'));
      expect(seen, contains('uploading 100'));
      final after = c.read(submitFlowProvider('c_1'));
      expect(after.failed, isTrue);
      expect(after.files.single.status, AttachmentStatus.done);
      expect(
        (await c.read(repositoryProvider).drafts()).single.briefId,
        'c_1',
        reason: 'the draft stays until the API confirms',
      );
    });
  });

  group('surfaces', () {
    test(
      'live briefs feed the closing-soon widget; polls stay preview',
      () async {
        final api = FakeApi();
        api.data('GET', '/challenges/browse', {
          'items': [
            challengeJson({'effectiveDeadline': '2026-10-17T16:00:00.000Z'}),
          ],
          'pageCount': 1,
          'page': 1,
        });
        final c = await _container(api);
        await c
            .read(repositoryProvider)
            .saveDraft(Draft(briefId: 'c_1', title: 'Sunday', editedAt: _now));
        final inputs = await surfaceInputs(c.read, _now);
        final preview = SurfaceInputs.demo(_now);
        expect([for (final b in inputs.briefs) b.id], ['c_1']);
        expect(inputs.draftBriefId, 'c_1');
        expect(inputs.polls.length, preview.polls.length);
        expect(inputs.now, _now);

        api.offline = true;
        final offline = await surfaceInputs(c.read, _now);
        expect(offline.briefs, hasLength(1), reason: 'the session copy');
      },
    );

    test(
      'with no draft on the phone, Continue my draft is not offered',
      () async {
        final api = FakeApi();
        api.data('GET', '/challenges/browse', {
          'items': <Object>[],
          'pageCount': 1,
          'page': 1,
        });
        final c = await _container(api);
        expect((await surfaceInputs(c.read, _now)).draftBriefId, isNull);
      },
    );

    test('preview keeps the demo inputs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      final inputs = await surfaceInputs(c.read, _now);
      final demo = SurfaceInputs.demo(_now);
      expect(
        [for (final b in inputs.briefs) b.id],
        [for (final b in demo.briefs) b.id],
      );
      expect(inputs.draftBriefId, demo.draftBriefId);
    });
  });
}
