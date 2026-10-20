import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';
import 'package:iqly_mobile/data/polls_service.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/activations/activations_state.dart';
import 'package:iqly_mobile/ui/recording_player.dart';

import '../../support/polls_activations_json.dart';

final _now = DateTime.utc(2026, 10, 17, 21);
final _f = PollsActivationsJson(_now);

String _at(Duration ago) => _f.at(ago);

http.Response _ok(Object? data, {int status = 200}) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _no(int status, String code) => http.Response(
  jsonEncode({
    'success': false,
    'error': {'code': code, 'message': ''},
  }),
  status,
  headers: {'content-type': 'application/json'},
);

/// An API answering from [routes] by `METHOD /path`, keeping every request.
class _Api {
  _Api(this.routes);

  final Map<String, http.Response Function(http.Request r)> routes;
  final requests = <http.Request>[];

  late final api = ApiClient(
    tokens: MemoryTokenStore('signed.token'),
    baseUrl: 'https://api.test',
    client: MockClient((r) async {
      requests.add(r);
      return routes['${r.method} ${r.url.path}']?.call(r) ??
          _no(404, 'NOT_FOUND');
    }),
  );

  late final link = AccountLink(
    api: api,
    store: MemoryLocalStore(),
    outbox: Outbox(MemoryLocalStore()),
    userId: () => 'u_1',
  );

  List<http.Request> to(String route) => [
    for (final r in requests)
      if ('${r.method} ${r.url.path}' == route) r,
  ];
}

void main() {
  group('polls from the API', () {
    test('no counts before a vote read as zeros; a vote counts', () {
      final open = pollFromJson(_f.pollJson())!;
      expect(open.voted, isFalse);
      expect(open.votes, [0, 0, 0]);
      expect(open.shares, [0, 0, 0]);
      expect(open.closedAt(_now), isFalse);

      final voted = pollFromJson(_f.pollJson(chosen: 0, votes: [96, 71, 47]))!;
      expect(voted.chosen, 0);
      expect(voted.total, 214);
      expect(voted.shares, [45, 33, 22]);

      final early = pollFromJson(_f.pollJson(closed: true, votes: [1, 2, 3]))!;
      expect(early.closedAt(_now), isTrue, reason: 'closed says so');
      expect(pollFromJson({..._f.pollJson(), 'choices': []}), isNull);
      expect(pollFromJson(_f.pollJson(chosen: 7))!.chosen, isNull);
    });

    test('the list keeps the API order and the business art', () {
      final businesses = pollBusinessesFromJson({
        'businesses': [
          {
            'id': 'org_harbour',
            'name': 'Harbour Telecom',
            'logoUrl': 'https://api.test/logo',
            'coverUrl': null,
            'bannerUrl': 'https://api.test/banner',
            'polls': [
              _f.pollJson(id: 'p_2', chosen: 1, votes: [58, 81, 37]),
            ],
          },
          {
            'id': 'org_sunline',
            'name': 'Sunline Foods',
            'polls': [_f.pollJson(), _f.pollJson(id: 'p_3')],
          },
          {'id': 'org_empty', 'name': 'Nobody', 'polls': []},
        ],
      });
      expect(
        [for (final b in businesses) b.name],
        ['Harbour Telecom', 'Sunline Foods'],
      );
      expect(businesses.first.logo, 'https://api.test/logo');
      expect(businesses.first.cover, isNull);
      expect(businesses.first.banner, 'https://api.test/banner');
      expect(businesses.first.allAnswered, isTrue);
      expect(businesses.last.unanswered, 2);
    });

    test('detail, vote and a refusal', () async {
      final api = _Api({
        'GET /polls/p_1': (_) => _ok(_f.pollJson()),
        'POST /polls/p_1/vote': (r) {
          final choice = (jsonDecode(r.body) as Map)['choice'];
          return choice == 0
              ? _ok(_f.pollJson(chosen: 0, votes: [96, 71, 47]))
              : _no(409, 'POLL_ALREADY_VOTED');
        },
      });
      final service = LivePollsService(api.link);
      final alone = await service.poll('p_1');
      expect(alone.id, 'org_sunline');
      expect(alone.name, 'Sunline Foods');
      expect(alone.polls.single.id, 'p_1');

      final counted = await service.vote('p_1', 0);
      expect(counted.chosen, 0);
      expect(counted.shares, [45, 33, 22]);
      expect(jsonDecode(api.to('POST /polls/p_1/vote').single.body), {
        'choice': 0,
      });
      await expectLater(
        service.vote('p_1', 1),
        throwsA(
          isA<ApiRefused>().having((r) => r.code, 'code', 'POLL_ALREADY_VOTED'),
        ),
      );
    });
  });

  group('activations from the API', () {
    Activation read(Map<String, Object?> json) =>
        activationFromJson(json, now: _now)!;

    test('every phase the API names reads as the same phase', () {
      final now = _now.toLocal();
      expect(read(_f.activationJson()).phaseAt(now), ActivationPhase.offer);
      expect(
        read(_f.activationJson(progress: _f.runJson())).phaseAt(now),
        ActivationPhase.started,
      );
      expect(
        read(
          _f.activationJson(
            progress: _f.runJson(confirmedAt: [_at(const Duration(hours: 2))]),
          ),
        ).phaseAt(now),
        ActivationPhase.confirming,
      );
      final stuck = read(
        _f.activationJson(
          progress: _f.runJson(
            confirmedAt: [_at(const Duration(hours: 24, minutes: 20))],
          ),
        ),
      );
      expect(stuck.phaseAt(now), ActivationPhase.notConfirmed);
      expect(stuck.waitingStep, 1);
      final checking = read(
        _f.activationJson(
          progress: _f.runJson(
            confirmedAt: [_at(const Duration(days: 1))],
            proof: _f.proofJson(),
          ),
        ),
      );
      expect(checking.phaseAt(now), ActivationPhase.checking);
      expect(
        checking.progress!.proof!.video.length,
        const Duration(seconds: 42),
      );
      expect(
        checking.progress!.proof!.video.source.toString(),
        'https://api.test/activations/proofs/pr_1/video',
      );
      final refused = read(
        _f.activationJson(
          progress: _f.runJson(
            confirmedAt: [_at(const Duration(days: 1))],
            proof: _f.proofJson(status: 'rejected', reason: 'Too short.'),
          ),
        ),
      );
      expect(refused.phaseAt(now), ActivationPhase.notAccepted);
      expect(refused.progress!.proof!.notAccepted, 'Too short.');
      final paid = read(
        _f.activationJson(
          progress: _f.runJson(
            status: 'paid',
            confirmedAt: [for (var i = 0; i < 3; i++) _at(Duration.zero)],
            paidAt: _at(Duration.zero),
          ),
        ),
      );
      expect(paid.phaseAt(now), ActivationPhase.credited);
      expect(paid.progress!.ledgerId, 'l_9');
    });

    group('the rules of 19 Oct (activationStepProof)', () {
      Activation gated(Map<String, Object?> json, {bool stepProof = true}) =>
          activationFromJson(json, now: _now, stepProof: stepProof)!;

      final proofByStep = _f.activationJson(
        confirmationMode: 'proof',
        rewardMode: 'per_step',
        stepRewards: [0, 50000, 100000],
        progress: _f.runJson(
          confirmedAt: [_at(const Duration(hours: 3)), _at(Duration.zero)],
          proof: _f.proofJson(status: 'accepted', step: 1),
          refCode: 'IQ-AB12C',
          stepPayouts: [_f.payoutJson(1, 50000, Duration.zero)],
        ),
      );

      test('a proof-mode run paid by step reads its modes and payouts', () {
        final a = gated(proofByStep);
        expect(a.confirmationMode, ConfirmationMode.proof);
        expect(a.rewardMode, RewardMode.perStep);
        expect([for (final s in a.steps) s.rewardKobo], [0, 50000, 100000]);
        final run = a.progress!;
        expect(run.refCode, 'IQ-AB12C');
        final payout = run.stepPayouts.single;
        expect(
          (payout.step, payout.kobo, payout.ledgerId),
          (1, 50000, 'l_step_1'),
        );
        expect(payout.paidAt.isAtSameMomentAs(_now), isTrue);
        expect(a.phaseAt(_now.toLocal()), ActivationPhase.recording);
        expect(a.proofStep, 2);
        expect(a.showsStepRewards, isTrue);
      });

      test('a postback run per run reads its code', () {
        final a = gated(
          _f.activationJson(
            confirmationMode: 'postback',
            rewardMode: 'per_run',
            progress: _f.runJson(
              started: const Duration(hours: 25),
              refCode: 'IQ-7K3P2',
            ),
          ),
        );
        expect(a.confirmationMode, ConfirmationMode.postback);
        expect(a.rewardMode, RewardMode.perRun);
        expect(a.progress!.refCode, 'IQ-7K3P2');
        expect(a.phaseAt(_now.toLocal()), ActivationPhase.notConfirmed);
        expect(a.proofStep, 0);
      });

      test('with the gate off they read as before, so today’s rules hold', () {
        final a = gated(proofByStep, stepProof: false);
        expect(a.confirmationMode, isNull);
        expect(a.rewardMode, RewardMode.perRun);
        expect([for (final s in a.steps) s.rewardKobo], [null, null, null]);
        expect(a.progress!.refCode, isNull);
        expect(a.progress!.stepPayouts, isEmpty);
        expect(a.phaseAt(_now.toLocal()), ActivationPhase.checking);
        expect(read(proofByStep).confirmationMode, isNull);
      });

      test('missing or unknown fields keep today’s meaning', () {
        final bare = gated(_f.activationJson(progress: _f.runJson()));
        expect(bare.confirmationMode, isNull);
        expect(bare.rewardMode, RewardMode.perRun);
        expect(bare.progress!.stepPayouts, isEmpty);
        expect(bare.phaseAt(_now.toLocal()), ActivationPhase.started);
        final odd = gated(
          _f.activationJson(
            confirmationMode: 'carrier_pigeon',
            rewardMode: 'per_minute',
          ),
        );
        expect(odd.confirmationMode, isNull);
        expect(odd.rewardMode, RewardMode.perRun);
      });

      test('a step the business holds is the business’s, never proof’s', () {
        Activation postback({List<Object?>? held}) => gated(
          _f.activationJson(
            confirmationMode: 'postback',
            progress: {
              ..._f.runJson(
                started: const Duration(hours: 30),
                refCode: 'IQ-7K3P2',
              ),
              'heldSteps': ?held,
            },
          ),
        );
        final held = postback(
          held: [
            _f.heldJson(0, const Duration(hours: 2)),
            {'until': _f.inn(const Duration(hours: 3))},
            'nonsense',
          ],
        );
        final step = held.progress!.heldSteps.single;
        expect(step.step, 0);
        expect(
          step.until!.isAtSameMomentAs(_now.add(const Duration(hours: 2))),
          isTrue,
        );
        expect(held.heldAt(0), isTrue);
        expect(held.phaseAt(_now.toLocal()), ActivationPhase.confirming);
        expect(held.proofStep, isNull, reason: 'no 24 hour fallback');
        expect(held.waitingStep, 0);
        expect(held.waitingSince, isNull);

        final today = postback();
        expect(today.progress!.heldSteps, isEmpty);
        expect(today.phaseAt(_now.toLocal()), ActivationPhase.notConfirmed);
        expect(today.proofStep, 0);

        final closedHeld = gated(
          _f.activationJson(
            status: 'closed',
            confirmationMode: 'postback',
            progress: _f.runJson(
              started: const Duration(hours: 30),
              heldSteps: [_f.heldJson(0, const Duration(hours: 2))],
            ),
          ),
        );
        expect(closedHeld.closedAt(_now.toLocal()), isTrue);
        expect(closedHeld.phaseAt(_now.toLocal()), ActivationPhase.confirming);

        final off = activationFromJson(
          _f.activationJson(
            confirmationMode: 'postback',
            progress: _f.runJson(
              started: const Duration(hours: 30),
              heldSteps: [_f.heldJson(0, const Duration(hours: 2))],
            ),
          ),
          now: _now,
        )!;
        expect(off.progress!.heldSteps, isEmpty);
      });

      test('a malformed payout is left out', () {
        final a = gated(
          _f.activationJson(
            confirmationMode: 'proof',
            rewardMode: 'per_step',
            progress: {
              ..._f.runJson(),
              'stepPayouts': [
                {'step': 0, 'kobo': 100},
                _f.payoutJson(1, 200, Duration.zero),
                'nonsense',
              ],
            },
          ),
        );
        expect([for (final p in a.progress!.stepPayouts) p.step], [1]);
      });
    });

    test('closed early: ended from the run’s end, never still open', () {
      final ended = read(
        _f.activationJson(
          status: 'closed',
          progress: _f.runJson(
            status: 'expired',
            expiredAt: _at(const Duration(hours: 3)),
          ),
        ),
      );
      expect(ended.phaseAt(_now.toLocal()), ActivationPhase.expired);
      expect(
        ended.closesAt.isAtSameMomentAs(
          _now.subtract(const Duration(hours: 3)),
        ),
        isTrue,
      );
      final offer = read(_f.activationJson(status: 'closed'));
      expect(offer.closedAt(_now.toLocal()), isTrue);
      expect(offer.phaseAt(_now.toLocal()), ActivationPhase.expired);
    });

    test('its art is the API’s, never a sample business’s', () {
      final a = read(_f.activationJson());
      expect(a.live, isTrue);
      expect(a.logoUrl, 'https://api.test/profiles/brands/org_harbour/logo');
      expect(a.imageUrl, 'https://api.test/activations/a_1/image?v=1');
      expect(a.steps[1].howTo, 'Settings → Verification. About 2 min');
      expect(a.link, Uri.parse('https://harbour.example/app'));
    });

    test('the list adds the runs only My activations has', () async {
      final api = _Api({
        'GET /activations': (_) => _ok({
          'items': [_f.activationJson(id: 'a_1')],
        }),
        'GET /activations/mine': (r) => r.url.queryParameters['cursor'] == null
            ? _ok({
                'items': [_f.activationJson(id: 'a_1', progress: _f.runJson())],
                'nextCursor': 'next',
              })
            : _ok({
                'items': [
                  _f.activationJson(id: 'a_old', progress: _f.runJson()),
                ],
                'nextCursor': null,
              }),
      });
      final all = await LiveActivationsService(
        api.link,
        clock: () => _now,
      ).activations();
      expect([for (final a in all) a.id], ['a_1', 'a_old']);
      expect(api.to('GET /activations/mine'), hasLength(2));
      expect(Recordings.signedIn?.token, 'signed.token');
      expect(
        Recordings.headersFor(
          Uri.parse('https://api.test/activations/proofs/x/video'),
        ),
        {'authorization': 'Bearer signed.token'},
      );
      expect(
        Recordings.headersFor(Uri.parse('https://elsewhere.test/v.mp4')),
        isEmpty,
      );
    });

    test('start, refresh and proof answer the activation', () async {
      final api = _Api({
        'POST /activations/a_1/start': (_) =>
            _ok(_f.activationJson(progress: _f.runJson()), status: 201),
        'GET /activations/a_1': (_) => _ok(_f.activationJson()),
        'POST /activations/a_1/proof': (_) => _ok(
          _f.activationJson(
            progress: _f.runJson(
              confirmedAt: [_at(const Duration(days: 1))],
              proof: _f.proofJson(),
            ),
          ),
        ),
        'POST /activations/a_2/start': (_) => _no(409, 'ACTIVATION_FULL'),
      });
      final service = LiveActivationsService(api.link, clock: () => _now);
      expect((await service.start('a_1')).started, isTrue);
      expect((await service.refresh('a_1')).started, isFalse);
      final sent = await service.sendProof(
        'a_1',
        step: 1,
        uploadId: 'up_1',
        video: const ProofVideo(name: 'p.mp4', bytes: 10),
        note: 'Same phone',
      );
      expect(sent.phaseAt(_now.toLocal()), ActivationPhase.checking);
      expect(jsonDecode(api.to('POST /activations/a_1/proof').single.body), {
        'step': 1,
        'uploadId': 'up_1',
        'note': 'Same phone',
      });
      await expectLater(
        service.start('a_2'),
        throwsA(
          isA<ApiRefused>().having((r) => r.code, 'code', 'ACTIVATION_FULL'),
        ),
      );
    });

    test('the recording uploads from its file with its length', () async {
      final dir = await Directory.systemTemp.createTemp('proof');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/run.mov')..writeAsBytesSync([1, 2, 3]);
      final api = _Api({
        'POST /activations/a_1/proof/uploads': (r) => _ok({
          'id': 'up_1',
          'name': 'run.mov',
          'bytes': 3,
          'lengthSeconds': 42,
        }, status: 201),
      });
      final service = LiveActivationsService(api.link, clock: () => _now);
      final events = await service
          .upload(
            'a_1',
            ProofVideo(
              name: 'run.mov',
              bytes: 3,
              length: const Duration(milliseconds: 41200),
              source: file.uri,
            ),
          )
          .toList();
      expect(events.last.id, 'up_1');
      expect(events.last.progress, 1);
      expect(events.where((e) => e.id == null), isNotEmpty);
      final body = utf8.decode(
        api.to('POST /activations/a_1/proof/uploads').single.bodyBytes,
        allowMalformed: true,
      );
      expect(body, contains('name="lengthSeconds"\r\n\r\n42'));
      expect(body, contains('filename="run.mov"'));
      expect(body, contains('content-type: video/quicktime'));
    });

    test(
      'a refused upload says why; a recording that cannot be read fails',
      () async {
        final dir = await Directory.systemTemp.createTemp('proof');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/notes.txt')..writeAsBytesSync([1]);
        final api = _Api({
          'POST /activations/a_1/proof/uploads': (_) =>
              _no(415, 'FILE_TYPE_NOT_ALLOWED'),
        });
        final service = LiveActivationsService(api.link, clock: () => _now);
        await expectLater(
          service
              .upload(
                'a_1',
                ProofVideo(name: 'notes.txt', bytes: 1, source: file.uri),
              )
              .last,
          throwsA(
            isA<ApiRefused>().having(
              (r) => ProofRefusal.fromCode(r.code),
              'refusal',
              ProofRefusal.kind,
            ),
          ),
        );
        await expectLater(
          service
              .upload(
                'a_1',
                ProofVideo(
                  name: 'x.mp4',
                  bytes: 1,
                  source: Uri.parse('content://media/1'),
                ),
              )
              .last,
          throwsA(isA<ApiUnreachable>()),
        );
        expect(ProofRefusal.fromCode('VIDEO_TOO_LONG'), ProofRefusal.length);
        expect(ProofRefusal.fromCode('FILE_TOO_LARGE'), ProofRefusal.size);
        for (final code in [
          'ACTIVATION_CLOSED',
          'ACTIVATION_NOT_STARTED',
          'ACTIVATION_COMPLETION_EXPIRED',
          'ACTIVATION_NOT_FOUND',
        ]) {
          expect(ProofRefusal.fromCode(code), ProofRefusal.ended, reason: code);
        }
        expect(
          ProofRefusal.fromCode('ACTIVATION_COMPLETION_PAID'),
          ProofRefusal.paid,
        );
        expect(ProofRefusal.fromCode('ACCOUNT_CLOSING'), ProofRefusal.closing);
        expect(ProofRefusal.fromCode('RATE_LIMITED'), isNull);
        expect(videoMediaType('a.MP4'), 'video/mp4');
        expect(videoMediaType('a.webm'), 'video/webm');
        expect(videoMediaType('a.3gp'), 'video/3gpp');
        expect(videoMediaType('a.txt'), 'application/octet-stream');
      },
    );

    test('an upload left before it lands is dropped once it has', () async {
      final dir = await Directory.systemTemp.createTemp('proof');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/run.mp4')..writeAsBytesSync([1, 2]);
      final api = _Api({
        'POST /activations/a_1/proof/uploads': (_) =>
            _ok({'id': 'up_7'}, status: 201),
        'DELETE /activations/a_1/proof/uploads/up_7': (_) =>
            http.Response('', 204),
      });
      final service = LiveActivationsService(api.link, clock: () => _now);
      final subscription = service
          .upload(
            'a_1',
            ProofVideo(name: 'run.mp4', bytes: 2, source: file.uri),
          )
          .listen((_) {});
      await subscription.cancel();
      for (
        var i = 0;
        i < 20 && api.to('DELETE /activations/a_1/proof/uploads/up_7').isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(
        api.to('DELETE /activations/a_1/proof/uploads/up_7'),
        hasLength(1),
      );
    });
  });
}
