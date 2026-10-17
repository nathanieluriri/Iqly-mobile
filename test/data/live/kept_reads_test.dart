import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/live/kept_reads.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_notifications_service.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/token_store.dart';

import 'live_data_fixtures.dart';

/// An API whose every answer [answer] decides; null never answers.
ApiClient _api(Future<http.Response>? Function(http.Request r) answer) =>
    ApiClient(
      tokens: MemoryTokenStore('t'),
      baseUrl: 'https://api.test',
      client: MockClient((r) => answer(r) ?? Completer<http.Response>().future),
    );

Future<http.Response> _json(int status, Object body) async =>
    http.Response(jsonEncode(body), status);

Future<http.Response> _fault(int status) => _json(status, {
  'success': false,
  'error': {'code': 'FAULT', 'message': 'Down.'},
});

void main() {
  group('orKept', () {
    ({String copy}) kept() => (copy: 'kept');

    test('the fetch wins when it answers in time', () {
      fakeAsync((async) {
        String? got;
        orKept(
          Future.delayed(const Duration(seconds: 2), () => 'fresh'),
          Future.value(kept()),
        ).then((v) => got = v);
        async.elapse(const Duration(seconds: 2));
        expect(got, 'fresh');
      });
    });

    test('with a copy, the wait ends at 3 s; the fetch carries on', () {
      fakeAsync((async) {
        String? got;
        var landed = false;
        final fetching = Future.delayed(const Duration(seconds: 20), () {
          landed = true;
          return 'fresh';
        });
        orKept(fetching, Future.value(kept())).then((v) => got = v);
        async.elapse(const Duration(milliseconds: 2900));
        expect(got, isNull);
        async.elapse(const Duration(milliseconds: 100));
        expect(got, 'kept');
        async.elapse(const Duration(seconds: 17));
        expect(landed, isTrue);
      });
    });

    test('without a copy the fetch decides, however long it takes', () {
      fakeAsync((async) {
        String? got;
        orKept(
          Future.delayed(const Duration(seconds: 19), () => 'fresh'),
          Future.value(null),
        ).then((v) => got = v);
        async.elapse(const Duration(seconds: 18));
        expect(got, isNull);
        async.elapse(const Duration(seconds: 1));
        expect(got, 'fresh');
      });
    });

    test('no answer, a timeout, TLS, a throttle or a fault answers the copy '
        'at once', () async {
      for (final error in [
        const ApiUnreachable(),
        const ApiUnreachable(nothingSent: true),
        const ApiRefused(500),
        const ApiRefused(502),
        const ApiRefused(503),
        const ApiRefused(429),
        const ApiRefused(408),
      ]) {
        expect(
          await orKept<String>(Future.error(error), Future.value(kept())),
          'kept',
          reason: '$error',
        );
      }
    });

    test('a definite refusal fails, whatever is kept', () async {
      for (final status in [400, 401, 403, 404, 409]) {
        await expectLater(
          orKept<String>(
            Future.error(ApiRefused(status)),
            Future.value(kept()),
          ),
          throwsA(isA<ApiRefused>()),
          reason: '$status',
        );
      }
    });

    test('a copy the store cannot read is no copy', () async {
      expect(
        await orKept<String>(Future.value('fresh'), Future.error('disk')),
        'fresh',
      );
      await expectLater(
        orKept<String>(
          Future.error(const ApiUnreachable()),
          Future.error('disk'),
        ),
        throwsA(isA<ApiUnreachable>()),
      );
    });
  });

  group('live reads', () {
    late MemoryLocalStore store;

    setUp(() async {
      store = MemoryLocalStore();
      await store.writeCache('u_1', LiveCacheKeys.briefs, [challengeJson()]);
    });

    LiveRepository repository(ApiClient api) => LiveRepository(
      api: api,
      store: store,
      mode: allLive,
      demo: DemoRepository(DemoData()),
      userId: 'u_1',
    );

    test('briefs: a network that never answers shows the copy kept after '
        '3 s, not the 20 s timeout', () {
      fakeAsync((async) {
        List<Object?>? got;
        repository(_api((_) => null))
            .briefs(load: BriefsLoad.feed)
            .then((v) => got = v);
        async.elapse(const Duration(milliseconds: 2900));
        expect(got, isNull);
        async.elapse(const Duration(milliseconds: 100));
        expect(got, hasLength(1));
      });
    });

    test('briefs: a fault or a throttle answers the copy kept; a refresh '
        'does not', () async {
      for (final status in [500, 503, 429]) {
        final repo = repository(_api((_) => _fault(status)));
        expect(await repo.briefs(load: BriefsLoad.feed), hasLength(1));
        await expectLater(
          repo.briefs(load: BriefsLoad.refresh),
          throwsA(isA<ApiRefused>()),
        );
      }
    });

    test('a TLS failure answers the briefs kept', () async {
      final repo = repository(
        _api((_) => throw const HandshakeException('WRONG_VERSION_NUMBER')),
      );
      expect(await repo.briefs(load: BriefsLoad.feed), hasLength(1));
    });

    test('brief detail answers the brief kept on a fault', () async {
      final repo = repository(_api((_) => _fault(503)));
      expect((await repo.brief('c_1'))!.title, 'Make Sunday data day');
      expect(await repo.brief('gone'), isNull);
    });

    test('an answer that lands after the wait is kept for next time', () {
      fakeAsync((async) {
        final late = Completer<http.Response>();
        repository(_api((_) => late.future))
            .briefs(load: BriefsLoad.feed)
            .ignore();
        async.elapse(const Duration(seconds: 3));
        late.complete(
          _json(200, {
            'success': true,
            'data': {
              'items': [
                challengeJson(),
                challengeJson({'id': 'c_2'}),
              ],
              'pageCount': 1,
            },
          }),
        );
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 10));
        List<Object?>? kept;
        store
            .readCache('u_1', LiveCacheKeys.briefs)
            .then((e) => kept = e!.json as List<Object?>);
        async.flushMicrotasks();
        expect(kept, hasLength(2));
      });
    });

    test('the account reads answer the copy kept on a fault', () async {
      await store.writeCache('u_1', AccountKeys.profile, {'city': 'Yaba'});
      final link = AccountLink(
        api: _api((_) => _fault(502)),
        store: store,
        outbox: Outbox(store),
        userId: () => 'u_1',
      );
      expect(
        await link.fetch('/profiles/contributors/me', AccountKeys.profile),
        {'city': 'Yaba'},
      );
      await expectLater(
        link.fetch('/me/notification-preferences', AccountKeys.preferences),
        throwsA(isA<ApiRefused>()),
        reason: 'nothing kept',
      );
    });

    test('the notification feed answers the copy kept on a fault', () async {
      await store.writeCache('u_1', AccountKeys.notifications, {
        'items': <Object>[],
        'unseen': 0,
      });
      final feed = LiveNotificationsService(
        AccountLink(
          api: _api((_) => _fault(500)),
          store: store,
          outbox: Outbox(store),
          userId: () => 'u_1',
        ),
      );
      expect(await feed.notifications(), isEmpty);
    });
  });
}
