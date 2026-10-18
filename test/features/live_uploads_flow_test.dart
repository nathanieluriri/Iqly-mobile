import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/live/submit_queue.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/submit_data.dart';
import 'package:iqly_mobile/data/submit_service.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/drafts/drafts_state.dart';
import 'package:iqly_mobile/features/profile/account_sync.dart';
import 'package:iqly_mobile/features/submit/submit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/live/live_data_fixtures.dart';
import '../support/live_launch.dart';

/// The API as these tests script it; requests to [offline] routes fail as
/// a dropped connection does.
class _Server {
  _Server(this.routes);

  final Map<String, http.Response Function(http.Request)> routes;
  final requests = <http.Request>[];
  final offline = <String>{};

  late final api = ApiClient(
    tokens: MemoryTokenStore('t'),
    baseUrl: 'https://api.test',
    client: MockClient((r) async {
      requests.add(r);
      final route = '${r.method} ${r.url.path}';
      if (offline.contains(route)) {
        throw http.ClientException('offline', r.url);
      }
      return routes[route]?.call(r) ?? ok(page([]));
    }),
  );

  List<http.Request> to(String route) => [
    for (final r in requests)
      if ('${r.method} ${r.url.path}' == route) r,
  ];
}

Future<(ProviderContainer, MemoryLocalStore)> _launch(
  _Server server, {
  required Backend mode,
}) async {
  SharedPreferences.setMockInitialValues(signedInLive());
  final prefs = await SharedPreferences.getInstance();
  final store = MemoryLocalStore(clock: () => launchNow);
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => launchNow),
      localStoreProvider.overrideWithValue(store),
      ...liveOverrides(server.api, mode: mode),
    ],
  );
  addTearDown(c.dispose);
  addTearDown(() => c.read(outboxProvider).stop());
  startAccountSync(c);
  c
    ..listen(draftsProvider, (_, _) {})
    ..listen(submitFlowProvider('c_1'), (_, _) {});
  await c.read(draftsProvider.future);
  return (c, store);
}

AttachmentFile _file(String name) =>
    AttachmentFile(name: name, bytes: 3, read: () async => [1, 2, 3]);

/// Fills in the title, the answer and every question of [form].
SubmitFlowNotifier _filled(ProviderContainer c, SubmitForm form) {
  final flow = c.read(submitFlowProvider('c_1').notifier)
    ..setTitle('Sunday is data day')
    ..setAnswer('Give a bonus bundle on Sundays, every single week.');
  for (final q in form.questions) {
    q.choice ? flow.pick(q, q.options.first) : flow.type(q, 'Payday');
  }
  return flow;
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uploads live: each file goes up as picked, a dropped one is '
      'deleted, and an entry sent offline is queued, then goes once under '
      'one Idempotency-Key and its draft goes with it', () async {
    final made = <String, Map<String, Object?>>{};
    var uploads = 0;
    final server = _Server({
      'GET /challenges/c_1': (_) => ok(challengeJson()),
      'GET /submissions/mine/by-challenge/c_1': (_) => ok(null),
      'POST /submissions/uploads': (_) => ok({
        'id': 'up_${++uploads}',
        'kind': 'image',
        'expiresAt': '2026-10-18T10:00:00Z',
      }, status: 201),
      'DELETE /submissions/uploads/up_1': (_) => http.Response('', 204),
      'POST /submissions/challenges/c_1': (r) {
        final key = r.headers['idempotency-key']!;
        final row = made[key] ??= {
          ...submissionJson({'id': 's_9', 'challengeId': 'c_1'}),
          'entries': 13,
        };
        return ok(row, status: 201);
      },
    })..offline.add('POST /submissions/challenges/c_1');
    final (c, store) = await _launch(
      server,
      mode: Backend.of({...firstFeatures, LiveFeature.uploads}),
    );
    final form = (await c.read(submitOpeningProvider('c_1').future)).form!;
    final flow = _filled(c, form)..addFiles([_file('a.png'), _file('b.png')]);
    await _until(
      () => c
          .read(submitFlowProvider('c_1'))
          .files
          .every((a) => a.status == AttachmentStatus.done),
    );
    expect(server.to('POST /submissions/uploads'), hasLength(2));
    expect(server.to('POST /submissions/uploads').first.body, contains('c_1'));
    expect(
      [for (final a in c.read(submitFlowProvider('c_1')).files) a.uploadId],
      ['up_1', 'up_2'],
    );
    flow.removeFile(0);
    await _until(
      () => server.to('DELETE /submissions/uploads/up_1').isNotEmpty,
    );
    expect(server.to('DELETE /submissions/uploads/up_1'), hasLength(1));

    final result = await flow.send(form);
    expect(result!.queued, isTrue);
    expect(c.read(submitFlowProvider('c_1')).queued, isTrue);
    expect(made, isEmpty);
    expect(
      c.read(draftsProvider).value!.where((d) => d.briefId == 'c_1'),
      hasLength(1),
      reason: 'kept until the entry lands',
    );
    final queued = (await store.outbox('u_1')).single;
    expect(queued.kind, submitKind);
    expect(queued.payload['uploadIds'], ['up_2']);

    server.offline.clear();
    await c.read(outboxProvider).networkBack();
    await _until(() => made.isNotEmpty);
    await _until(
      () => c.read(draftsProvider).value!.every((d) => d.briefId != 'c_1'),
    );
    expect(made, hasLength(1));
    final sends = server.to('POST /submissions/challenges/c_1');
    expect({for (final r in sends) r.headers['idempotency-key']}, {queued.id});
    expect(sends.last.body, contains('["up_2"]'));
    expect(sends.last.body, isNot(contains('filename=')));
    expect(
      c.read(draftsProvider).value!.where((d) => d.briefId == 'c_1'),
      isEmpty,
    );
  });

  test('an upload refused for good says why under the files', () async {
    for (final (response, words) in [
      (
        refused(409, 'SUBMISSION_UPLOADS_LIMIT'),
        'Too many files waiting to send. Send or remove some first.',
      ),
      (
        refused(415, 'FILE_TYPE_NOT_ALLOWED'),
        'a.png is not a file this brief takes.',
      ),
      (refused(413, 'FILE_TOO_LARGE'), 'a.png exceeds 10 MB.'),
    ]) {
      final server = _Server({
        'GET /challenges/c_1': (_) => ok(challengeJson()),
        'GET /submissions/mine/by-challenge/c_1': (_) => ok(null),
        'POST /submissions/uploads': (_) => response,
      });
      final (c, _) = await _launch(
        server,
        mode: Backend.of({...firstFeatures, LiveFeature.uploads}),
      );
      await c.read(submitOpeningProvider('c_1').future);
      c.read(submitFlowProvider('c_1').notifier).addFiles([_file('a.png')]);
      await _until(
        () =>
            c.read(submitFlowProvider('c_1')).files.single.status ==
            AttachmentStatus.failed,
      );
      final flow = c.read(submitFlowProvider('c_1'));
      expect(flow.files.single.status, AttachmentStatus.failed);
      expect(flow.fileError, words);
    }
  });

  test('an upload gone by the send goes up again', () async {
    var uploads = 0;
    final server = _Server({
      'GET /challenges/c_1': (_) => ok(challengeJson()),
      'GET /submissions/mine/by-challenge/c_1': (_) => ok(null),
      'POST /submissions/uploads': (_) =>
          ok({'id': 'up_${++uploads}', 'kind': 'image'}, status: 201),
      'POST /submissions/challenges/c_1': (_) =>
          refused(404, 'SUBMISSION_UPLOAD_NOT_FOUND'),
    });
    final (c, _) = await _launch(
      server,
      mode: Backend.of({...firstFeatures, LiveFeature.uploads}),
    );
    final form = (await c.read(submitOpeningProvider('c_1').future)).form!;
    final flow = _filled(c, form)..addFiles([_file('a.png')]);
    await _until(
      () =>
          c.read(submitFlowProvider('c_1')).files.single.status ==
          AttachmentStatus.done,
    );
    final result = await flow.send(form);
    expect(result!.failure, SubmitFailure.uploadsGone);
    await _until(() => uploads == 2);
    await _until(
      () =>
          c.read(submitFlowProvider('c_1')).files.single.status ==
          AttachmentStatus.done,
    );
    expect(c.read(submitFlowProvider('c_1')).files.single.uploadId, 'up_2');
    expect(c.read(submitFlowProvider('c_1')).failed, isTrue);
  });

  test('uploads off: the files ride in the send, as before', () async {
    final server = _Server({
      'GET /challenges/c_1': (_) => ok(challengeJson()),
      'GET /submissions/mine/by-challenge/c_1': (_) => ok(null),
      'POST /submissions/challenges/c_1': (_) => ok({
        ...submissionJson({'id': 's_9', 'challengeId': 'c_1'}),
        'entries': 13,
      }, status: 201),
    });
    final (c, store) = await _launch(server, mode: allLive);
    final form = (await c.read(submitOpeningProvider('c_1').future)).form!;
    final flow = _filled(c, form)..addFiles([_file('a.png')]);
    await _until(
      () =>
          c.read(submitFlowProvider('c_1')).files.single.status ==
          AttachmentStatus.done,
    );
    final result = await flow.send(form);
    expect(result!.receipt, isNotNull);
    expect(server.to('POST /submissions/uploads'), isEmpty);
    expect(
      server.to('POST /submissions/challenges/c_1').single.body,
      contains('filename="a.png"'),
    );
    expect(await store.outbox('u_1'), isEmpty);
    expect(jsonEncode(c.read(submitFlowProvider('c_1')).step.name), '"sent"');
  });
}
