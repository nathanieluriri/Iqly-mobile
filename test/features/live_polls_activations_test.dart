import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/polls_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/activations/activation_screen.dart';
import 'package:iqly_mobile/features/activations/activations_routes.dart';
import 'package:iqly_mobile/features/activations/activations_screen.dart';
import 'package:iqly_mobile/features/activations/activations_state.dart';
import 'package:iqly_mobile/features/activations/my_activations_screen.dart';
import 'package:iqly_mobile/features/activations/proof_screen.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/help/help_request_screen.dart';
import 'package:iqly_mobile/features/polls/poll_sheet.dart';
import 'package:iqly_mobile/features/profile/edit_detail_screen.dart';
import 'package:iqly_mobile/features/polls/polls_routes.dart';
import 'package:iqly_mobile/features/polls/polls_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/surfaces/surfaces.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/live/live_data_fixtures.dart'
    show
        FixedBackend,
        challengeJson,
        firstFeatures,
        transactionJson,
        walletJson;
import '../support/live_launch.dart';
import '../support/polls_activations_json.dart';

final _json = PollsActivationsJson(launchNow);

/// 0.5.0's features with polls and activations on, as health has them once
/// contract 11 ships.
final _on = Backend.of({
  ...firstFeatures,
  LiveFeature.polls,
  LiveFeature.activations,
});

/// Today's staging: polls and activations absent from health.
final _off = Backend.of(firstFeatures);

const _flavour = 'Which flavour should we launch first?';
const _kiosk = 'When should a kiosk open in the morning?';
const _plan = 'Open a Harbour Telecom account and buy a 1GB plan';

/// One person's API: [routes] by `METHOD /path`, an empty list for any
/// other read. Every request is kept; while [offline] none is answered.
class _Api {
  _Api([Map<String, http.Response Function(http.Request r)>? routes])
    : routes = {
        'GET /me': (_) => _ok({
          'id': 'u_1',
          'name': 'Ada Obi',
          'email': 'ada@example.com',
          'status': 'active',
          'profile': null,
        }),
        'GET /polls': (_) => _ok(
          _json.pollsJson([
            _json.pollJson(
              id: 'p_2',
              question: _kiosk,
              chosen: 1,
              votes: [58, 81, 37],
              businessId: 'org_harbour',
              businessName: 'Harbour Telecom',
            ),
            _json.pollJson(),
          ]),
        ),
        'GET /activations': (_) => _ok({
          'items': [_json.activationJson()],
        }),
        'GET /activations/a_1': (_) => _ok(_json.activationJson()),
        ...?routes,
      };

  final Map<String, http.Response Function(http.Request r)> routes;
  final requests = <http.Request>[];
  bool offline = false;

  List<String> get paths => [for (final r in requests) r.url.path];

  List<http.Request> to(String route) => [
    for (final r in requests)
      if ('${r.method} ${r.url.path}' == route) r,
  ];

  late final client = ApiClient(
    tokens: MemoryTokenStore('t'),
    baseUrl: 'https://api.test',
    client: MockClient((r) async {
      requests.add(r);
      if (offline) throw http.ClientException('offline', r.url);
      return routes['${r.method} ${r.url.path}']?.call(r) ??
          _ok({'items': <Object>[], 'nextCursor': null, 'pageCount': 1});
    }),
  );
}

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

http.Response _notDue(Map<String, Object?> details) => http.Response(
  jsonEncode({
    'success': false,
    'error': {
      'code': 'ACTIVATION_PROOF_NOT_DUE',
      'message': '',
      'details': details,
    },
  }),
  409,
  headers: {'content-type': 'application/json'},
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.byWidgetPredicate(
  (w) => w is IqButton && w.label == label,
  description: 'IqButton "$label"',
);

String _at(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

/// Hands every upload straight back as landed, or refused with [refusal].
class _Uploads extends LiveActivationsService {
  _Uploads(super.link, {this.refusal, super.stepProof});

  final ApiRefused? refusal;

  @override
  Stream<ProofUpload> upload(String id, ProofVideo video) {
    final refusal = this.refusal;
    return refusal == null
        ? Stream.value(const ProofUpload(1, id: 'up_1'))
        : Stream.error(refusal);
  }
}

void main() {
  group('polls and activations on', () {
    testWidgets('Discover and More show the API’s, never the samples', (
      tester,
    ) async {
      final api = _Api({
        'GET /challenges/browse': (_) => _ok({
          'items': [
            challengeJson({'brandName': 'Lagoon Data', 'audienceFilters': {}}),
          ],
          'pageCount': 1,
        }),
      });
      final (_, router) = await pumpLiveLaunch(
        tester,
        Routes.home,
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Quick polls'), findsOneWidget);
      expect(find.text(_kiosk), findsOneWidget);
      expect(find.text(_flavour), findsOneWidget);
      expect(find.text('Activations'), findsOneWidget);
      expect(find.text(_plan), findsOneWidget);
      for (final sample in ['Orchid Foods', 'Kudi Box', 'Unibooks']) {
        expect(find.textContaining(sample), findsNothing);
      }
      expect(api.paths, containsAll(['/polls', '/activations']));

      router.go(Routes.more);
      await tester.pumpAndSettle();
      expect(find.text('Quick polls'), findsOneWidget);
      expect(find.text('Activations'), findsOneWidget);
    });

    testWidgets('a vote goes to the API and its results show', (tester) async {
      final api = _Api({
        'POST /polls/p_1/vote': (_) =>
            _ok(_json.pollJson(chosen: 0, votes: [96, 71, 47])),
      });
      await pumpLiveLaunch(
        tester,
        pollsOf('org_sunline'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      expect(find.byType(PollSheet), findsOneWidget);
      await _tap(tester, find.text('Zobo and ginger'));
      expect(jsonDecode(api.to('POST /polls/p_1/vote').single.body), {
        'choice': 0,
      });
      expect(find.text('You voted · 214 votes'), findsOneWidget);
      expect(find.textContaining('Couldn’t send'), findsNothing);
    });

    testWidgets('a vote the API turns down reads the poll again', (
      tester,
    ) async {
      final api = _Api({
        'POST /polls/p_1/vote': (_) => _no(409, 'POLL_ALREADY_VOTED'),
        'GET /polls/p_1': (_) =>
            _ok(_json.pollJson(chosen: 2, votes: [95, 71, 48])),
      });
      await pumpLiveLaunch(
        tester,
        pollsOf('org_sunline'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Zobo and ginger'));
      expect(find.text('Couldn’t send.'), findsOneWidget);
      expect(api.to('GET /polls/p_1'), hasLength(1));
      expect(find.text('You voted · 214 votes'), findsOneWidget);
    });

    testWidgets('a closed poll the API reports shows as closed', (
      tester,
    ) async {
      final api = _Api({
        'POST /polls/p_1/vote': (_) => _no(409, 'POLL_CLOSED'),
        'GET /polls/p_1': (_) =>
            _ok(_json.pollJson(closed: true, votes: [95, 71, 47])),
      });
      await pumpLiveLaunch(
        tester,
        pollsOf('org_sunline'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Tiger nut'));
      expect(find.text('Couldn’t send.'), findsOneWidget);
      expect(find.text('Final · 213 votes'), findsOneWidget);
    });

    testWidgets('no answer keeps the connection banner', (tester) async {
      final api = _Api();
      await pumpLiveLaunch(
        tester,
        pollsOf('org_sunline'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      api.offline = true;
      await _tap(tester, find.text('Zobo and ginger'));
      expect(
        find.text('Couldn’t send. Check your connection.'),
        findsOneWidget,
      );
      expect(find.text('You voted · 214 votes'), findsNothing);
    });

    testWidgets('a closing account goes to Restore', (tester) async {
      final api = _Api({
        'POST /polls/p_1/vote': (_) => _no(403, 'ACCOUNT_CLOSING'),
      });
      final (_, router) = await pumpLiveLaunch(
        tester,
        pollsOf('org_sunline'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Zobo and ginger'));
      expect(_at(router), Routes.restoreAccount);
    });

    testWidgets('a poll row in the feed opens its business’s polls', (
      tester,
    ) async {
      final api = _Api({
        'GET /notifications': (_) => _ok({
          'items': [
            {
              'id': 'n_1',
              'type': 'poll_results',
              'createdAt': _json.at(const Duration(minutes: 5)),
              'readAt': null,
              'title': 'Poll results are in',
              'body': 'Sunline Foods: “$_flavour”',
              'refs': {'pollId': 'p_9', 'activationId': null},
            },
          ],
          'nextCursor': null,
          'unseen': 1,
        }),
        'GET /polls/p_9': (_) => _ok(
          _json.pollJson(
            id: 'p_9',
            question: 'Where do you buy your noodles?',
            closed: true,
            chosen: 0,
            votes: [61, 24, 12],
          ),
        ),
      });
      await pumpLiveLaunch(
        tester,
        Routes.notifications,
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Poll results are in'));
      expect(api.to('GET /polls/p_9'), hasLength(1));
      expect(find.byType(PollSheet), findsOneWidget);
      expect(find.text('Where do you buy your noodles?'), findsOneWidget);
      expect(find.text('You voted · 97 votes'), findsOneWidget);
    });

    testWidgets('start goes to the API and the steps follow', (tester) async {
      final api = _Api({
        'POST /activations/a_1/start': (_) =>
            _ok(_json.activationJson(progress: _json.runJson()), status: 201),
      });
      await pumpLiveLaunch(
        tester,
        Routes.activations,
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ActivationsScreen), findsOneWidget);
      await _tap(tester, find.text(_plan));
      expect(find.byType(ActivationScreen), findsOneWidget);
      await _tap(tester, _button('Start activation'));
      expect(api.to('POST /activations/a_1/start'), hasLength(1));
      expect(find.text('Open Harbour Telecom'), findsOneWidget);
      expect(find.text('Not started · 3 steps'), findsOneWidget);
    });

    group('the rules of 19 Oct', () {
      final gated = Backend.of({..._on.live, LiveFeature.activationStepProof});

      Map<String, Object?> proofMode({Map<String, Object?>? progress}) =>
          _json.activationJson(confirmationMode: 'proof', progress: progress);

      testWidgets('proof mode: step 1 is recorded right after Start', (
        tester,
      ) async {
        var started = false;
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [proofMode()],
          }),
          'GET /activations/a_1': (_) => _ok(
            proofMode(
              progress: started ? _json.runJson(started: Duration.zero) : null,
            ),
          ),
          'POST /activations/a_1/start': (_) {
            started = true;
            return _ok(
              proofMode(progress: _json.runJson(started: Duration.zero)),
              status: 201,
            );
          },
          'POST /activations/a_1/proof': (_) => _ok(
            proofMode(
              progress: _json.runJson(
                started: Duration.zero,
                proof: _json.proofJson(step: 0),
              ),
            ),
          ),
        });
        await pumpLiveLaunch(
          tester,
          activationPath('a_1'),
          api: api.client,
          mode: gated,
          overrides: [
            activationsServiceProvider.overrideWith(
              (ref) =>
                  _Uploads(ref.watch(accountLinkProvider)!, stepProof: true),
            ),
          ],
        );
        await tester.pumpAndSettle();
        await _tap(tester, _button('Start activation'));
        expect(_button('Upload proof of step 1'), findsOneWidget);
        expect(find.text('Not confirmed after a day'), findsNothing);
        await _tap(tester, _button('Upload proof of step 1'));
        expect(find.byType(ProofScreen), findsOneWidget);
        expect(
          find.text('Record step 1. Harbour Telecom confirms it.'),
          findsOneWidget,
        );
        await _tap(tester, find.text('Choose a video'));
        await _tap(tester, _button('Send proof'));
        final sent = jsonDecode(
          api.to('POST /activations/a_1/proof').single.body,
        );
        expect(sent['step'], 0);
        expect(find.byType(ActivationScreen), findsOneWidget);
        expect(find.text('Checking with Harbour Telecom'), findsWidgets);
      });

      testWidgets('proof mode: once step 1 is accepted, step 2 is next', (
        tester,
      ) async {
        final next = proofMode(
          progress: _json.runJson(
            confirmedAt: [_json.at(Duration.zero)],
            proof: _json.proofJson(status: 'accepted', step: 0),
          ),
        );
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [next],
          }),
          'GET /activations/a_1': (_) => _ok(next),
        });
        await pumpLiveLaunch(
          tester,
          activationPath('a_1'),
          api: api.client,
          mode: gated,
        );
        await tester.pumpAndSettle();
        expect(find.text('Step 1 of 3 confirmed'), findsOneWidget);
        expect(_button('Upload proof of step 2'), findsOneWidget);
        expect(find.text('Your proof'), findsNothing);
      });

      testWidgets('without the gate the same run keeps today’s steps page', (
        tester,
      ) async {
        final started = proofMode(
          progress: _json.runJson(started: Duration.zero),
        );
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [started],
          }),
          'GET /activations/a_1': (_) => _ok(started),
        });
        await pumpLiveLaunch(
          tester,
          activationPath('a_1'),
          api: api.client,
          mode: _on,
        );
        await tester.pumpAndSettle();
        expect(find.text('Not started · 3 steps'), findsOneWidget);
        expect(find.textContaining('Upload proof'), findsNothing);
        expect(_button('Open Harbour Telecom'), findsOneWidget);
      });

      testWidgets('postback mode: a step the business holds waits on it, '
          'with no proof offered a day after the start', (tester) async {
        Map<String, Object?> postback({List<Map<String, Object?>>? held}) =>
            _json.activationJson(
              confirmationMode: 'postback',
              progress: _json.runJson(
                started: const Duration(hours: 25),
                refCode: 'IQ-7K3P2',
                heldSteps: held,
              ),
            );
        var held = postback(
          held: [_json.heldJson(0, const Duration(hours: 2))],
        );
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [held],
          }),
          'GET /activations/a_1': (_) => _ok(held),
        });
        await pumpLiveLaunch(
          tester,
          activationPath('a_1'),
          api: api.client,
          mode: gated,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Waiting for Harbour Telecom to confirm.'),
          findsOneWidget,
        );
        expect(find.text('No steps confirmed yet'), findsOneWidget);
        expect(find.textContaining('Upload proof'), findsNothing);
        expect(find.text('Not confirmed after a day'), findsNothing);
        expect(_button('Open Harbour Telecom'), findsOneWidget);

        held = postback();
        await _tap(
          tester,
          find.text('Waiting for Harbour Telecom to confirm.'),
        );
        expect(_button('Upload proof of step 1'), findsOneWidget);
        expect(find.text('Not confirmed after a day'), findsOneWidget);
      });

      testWidgets('postback mode: the run’s code shows and copies', (
        tester,
      ) async {
        final calls = <String>[];
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          calls.add('${call.method} ${call.arguments}');
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        final run = _json.activationJson(
          confirmationMode: 'postback',
          progress: _json.runJson(started: Duration.zero, refCode: 'IQ-7K3P2'),
        );
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [run],
          }),
          'GET /activations/a_1': (_) => _ok(run),
        });
        await pumpLiveLaunch(
          tester,
          activationPath('a_1'),
          api: api.client,
          mode: gated,
        );
        await tester.pumpAndSettle();
        expect(find.text('Your iQLY code: IQ-7K3P2'), findsOneWidget);
        expect(
          find.text('Enter it if the Harbour Telecom app asks for it.'),
          findsOneWidget,
        );
        calls.clear();
        await tester.tap(_button('Copy'));
        await tester.pump();
        await tester.pump();
        expect(calls.first, contains('IQ-7K3P2'));
        expect(find.text('Code copied'), findsOneWidget);
        await tester.pumpAndSettle();
      });

      for (final names in [true, false]) {
        testWidgets('a run under way asks for help, '
            '${names ? 'from its business by name' : 'from support'}', (
          tester,
        ) async {
          final run = _json.activationJson(
            progress: _json.runJson(started: Duration.zero),
          );
          final api = _Api({
            'GET /activations': (_) => _ok({
              'items': [run],
            }),
            'GET /activations/a_1': (_) => _ok(run),
          });
          await pumpLiveLaunch(
            tester,
            activationPath('a_1'),
            api: api.client,
            mode: Backend.of({
              ..._on.live,
              LiveFeature.support,
              if (names) LiveFeature.helpAuthorNames,
            }),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text('Ask for help'), 100);
          await _tap(tester, find.text('Ask for help'));
          expect(find.byType(HelpRequestScreen), findsOneWidget);
          expect(
            _button(names ? 'Send to Harbour Telecom' : 'Send to support'),
            findsOneWidget,
          );
        });
      }

      testWidgets('paid by step: Up to on the offer, Paid on a paid step', (
        tester,
      ) async {
        Map<String, Object?> byStep({Map<String, Object?>? progress}) =>
            _json.activationJson(
              confirmationMode: 'postback',
              rewardMode: 'per_step',
              stepRewards: [0, 50000, 100000],
              progress: progress,
            );
        var run = byStep();
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [run],
          }),
          'GET /activations/a_1': (_) => _ok(run),
        });
        final (container, router) = await pumpLiveLaunch(
          tester,
          activationPath('a_1'),
          api: api.client,
          mode: gated,
        );
        await tester.pumpAndSettle();
        expect(find.text('Up to ₦1,500'), findsOneWidget);
        expect(find.text('₦500'), findsOneWidget);
        expect(find.text('₦1,000'), findsOneWidget);
        expect(find.text('₦0'), findsNothing, reason: 'a step paying nothing');

        run = byStep(
          progress: _json.runJson(
            confirmedAt: [_json.at(Duration.zero), _json.at(Duration.zero)],
            stepPayouts: [_json.payoutJson(1, 50000, Duration.zero)],
          ),
        );
        await container.read(activationsProvider.notifier).refresh('a_1');
        await tester.pumpAndSettle();
        expect(find.text('Paid ₦500'), findsOneWidget);
        expect(find.text('₦1,000'), findsOneWidget);
        expect(find.text('Step 2 of 3 confirmed'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Your progress:'), 100);
        expect(find.text('₦500 earned of up to ₦1,500'), findsOneWidget);
      });

      const held =
          'Harbour Telecom has reported this step. It counts when its hold '
          'ends.';

      /// Postback mode, a day after the start: step 1's proof was turned
      /// down, then the business's server reported the step, which it holds.
      Map<String, Object?> refusedThenHeld({bool hold = true}) =>
          _json.activationJson(
            confirmationMode: 'postback',
            progress: _json.runJson(
              started: const Duration(hours: 26),
              refCode: 'IQ-7K3P2',
              proof: _json.proofJson(
                status: 'rejected',
                reason: 'The recording ends too soon.',
                step: 0,
              ),
              heldSteps: hold
                  ? [_json.heldJson(0, const Duration(hours: 20))]
                  : null,
            ),
          );

      testWidgets('a proof turned down, then the step reported and held: '
          'the step waits on the business, with nothing to record again', (
        tester,
      ) async {
        final run = refusedThenHeld();
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [run],
          }),
          'GET /activations/a_1': (_) => _ok(run),
        });
        await pumpLiveLaunch(
          tester,
          activationPath('a_1'),
          api: api.client,
          mode: Backend.of({...gated.live, LiveFeature.support}),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Waiting for Harbour Telecom to confirm.'),
          findsOneWidget,
        );
        expect(find.text('Record again'), findsNothing);
        expect(find.textContaining('Proof not accepted'), findsNothing);
        expect(find.textContaining('Upload proof'), findsNothing);
        expect(find.text('No steps confirmed yet'), findsOneWidget);
      });

      testWidgets('without the hold the same proof offers Record again', (
        tester,
      ) async {
        final run = refusedThenHeld(hold: false);
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [run],
          }),
          'GET /activations/a_1': (_) => _ok(run),
        });
        await pumpLiveLaunch(
          tester,
          activationPath('a_1'),
          api: api.client,
          mode: gated,
        );
        await tester.pumpAndSettle();
        expect(find.text('Record again'), findsOneWidget);
        expect(
          find.text('Proof not accepted. The recording ends too soon.'),
          findsOneWidget,
        );
      });

      for (final (name, run, words) in [
        ('held', refusedThenHeld(), held),
        (
          'not a day yet',
          _json.activationJson(
            confirmationMode: 'postback',
            progress: _json.runJson(
              started: const Duration(hours: 2),
              refCode: 'IQ-7K3P2',
            ),
          ),
          'Proof can be sent once a step has waited a day for Harbour '
              'Telecom.',
        ),
      ]) {
        testWidgets('Upload proof of a step that cannot be proven ($name) '
            'says why, and offers nothing to pick, upload or send', (
          tester,
        ) async {
          final api = _Api({
            'GET /activations': (_) => _ok({
              'items': [run],
            }),
            'GET /activations/a_1': (_) => _ok(run),
          });
          await pumpLiveLaunch(
            tester,
            proofPath('a_1'),
            api: api.client,
            mode: gated,
            overrides: [
              activationsServiceProvider.overrideWith(
                (ref) =>
                    _Uploads(ref.watch(accountLinkProvider)!, stepProof: true),
              ),
            ],
          );
          await tester.pumpAndSettle();
          expect(find.byType(ProofScreen), findsOneWidget);
          expect(find.text(words), findsOneWidget);
          expect(find.textContaining('Record step'), findsNothing);
          expect(find.text('Choose a video'), findsNothing);
          expect(_button('Send proof'), findsNothing);
          expect(_button('This activation has ended'), findsNothing);
          expect(api.paths.where((p) => p.contains('/proof')), isEmpty);
        });
      }

      testWidgets('proof mode: the business confirms the step by hand while '
          'its recording is picked; the refused send takes the recording out '
          'and drops its upload', (tester) async {
        var confirmed = false;
        Map<String, Object?> run() => proofMode(
          progress: _json.runJson(
            started: Duration.zero,
            confirmedAt: [if (confirmed) _json.at(Duration.zero)],
          ),
        );
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [run()],
          }),
          'GET /activations/a_1': (_) => _ok(run()),
          'POST /activations/a_1/proof': (_) {
            confirmed = true;
            return _notDue({'step': 1, 'dueAt': null});
          },
        });
        await pumpLiveLaunch(
          tester,
          proofPath('a_1'),
          api: api.client,
          mode: gated,
          overrides: [
            activationsServiceProvider.overrideWith(
              (ref) =>
                  _Uploads(ref.watch(accountLinkProvider)!, stepProof: true),
            ),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.text('Proof of step 1 · up to 60 seconds'), findsOneWidget);
        await _tap(tester, find.text('Choose a video'));
        expect(find.text('Choose a video'), findsNothing);
        await _tap(tester, _button('Send proof'));
        expect(api.to('POST /activations/a_1/proof'), hasLength(1));
        expect(find.byType(ProofScreen), findsOneWidget);
        expect(
          find.text('Send proof of the next step, one step at a time.'),
          findsOneWidget,
        );
        expect(find.text('Proof of step 2 · up to 60 seconds'), findsOneWidget);
        expect(find.text('Choose a video'), findsOneWidget);
        expect(tester.widget<IqButton>(_button('Send proof')).disabled, isTrue);
        expect(
          api.to('DELETE /activations/a_1/proof/uploads/up_1'),
          hasLength(1),
        );
      });

      testWidgets('a recording kept from before the step changed is taken '
          'out when Upload proof opens again', (tester) async {
        var confirmed = false;
        Map<String, Object?> run() => proofMode(
          progress: _json.runJson(
            started: Duration.zero,
            confirmedAt: [if (confirmed) _json.at(Duration.zero)],
          ),
        );
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [run()],
          }),
          'GET /activations/a_1': (_) => _ok(run()),
        });
        final (container, _) = await pumpLiveLaunch(
          tester,
          activationPath('a_1'),
          api: api.client,
          mode: gated,
          overrides: [
            activationsServiceProvider.overrideWith(
              (ref) =>
                  _Uploads(ref.watch(accountLinkProvider)!, stepProof: true),
            ),
          ],
        );
        await tester.pumpAndSettle();
        await _tap(tester, _button('Upload proof of step 1'));
        await _tap(tester, find.text('Choose a video'));
        expect(container.read(proofDraftProvider('a_1')).step, 0);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(container.read(proofDraftProvider('a_1')).hasVideo, isTrue);

        confirmed = true;
        await container.read(activationsProvider.notifier).refresh('a_1');
        await tester.pumpAndSettle();
        await _tap(tester, _button('Upload proof of step 2'));
        expect(find.text('Proof of step 2 · up to 60 seconds'), findsOneWidget);
        expect(find.text('Choose a video'), findsOneWidget);
        expect(container.read(proofDraftProvider('a_1')).hasVideo, isFalse);
        expect(
          api.to('DELETE /activations/a_1/proof/uploads/up_1'),
          hasLength(1),
        );
        expect(find.byType(ProofScreen), findsOneWidget);
      });

      testWidgets('closed while a step is held: the step still waits on the '
          'business, with what it pays, and nothing ended', (tester) async {
        final closedHeld = _json.activationJson(
          status: 'closed',
          confirmationMode: 'postback',
          rewardMode: 'per_step',
          stepRewards: [50000, 50000, 50000],
          progress: _json.runJson(
            started: const Duration(hours: 30),
            refCode: 'IQ-7K3P2',
            heldSteps: [_json.heldJson(0, const Duration(hours: 20))],
          ),
        );
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [closedHeld],
          }),
          'GET /activations/a_1': (_) => _ok(closedHeld),
        });
        await pumpLiveLaunch(
          tester,
          activationPath('a_1'),
          api: api.client,
          mode: gated,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Waiting for Harbour Telecom to confirm.'),
          findsOneWidget,
        );
        expect(find.text('₦500'), findsWidgets);
        expect(_button('This activation has ended'), findsNothing);
        expect(_button('Open Harbour Telecom'), findsNothing);
        expect(find.textContaining('IQ-7K3P2'), findsNothing);
        expect(find.textContaining('Upload proof'), findsNothing);
      });

      testWidgets('Upload proof of a held step says why, and offers nothing '
          'to pick, upload or send, even closed', (tester) async {
        final run = {...refusedThenHeld(), 'status': 'closed'};
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [run],
          }),
          'GET /activations/a_1': (_) => _ok(run),
        });
        await pumpLiveLaunch(
          tester,
          proofPath('a_1'),
          api: api.client,
          mode: gated,
          overrides: [
            activationsServiceProvider.overrideWith(
              (ref) =>
                  _Uploads(ref.watch(accountLinkProvider)!, stepProof: true),
            ),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProofScreen), findsOneWidget);
        expect(find.text(held), findsOneWidget);
        expect(find.textContaining('Record step'), findsNothing);
        expect(find.text('Choose a video'), findsNothing);
        expect(_button('Send proof'), findsNothing);
        expect(_button('This activation has ended'), findsNothing);
        expect(api.paths.where((p) => p.contains('/proof')), isEmpty);
      });

      for (final (name, details, words) in [
        (
          'held',
          {'step': 0, 'dueAt': null, 'heldUntil': _json.inn(Duration.zero)},
          held,
        ),
        (
          'not a day yet',
          {'step': 0, 'dueAt': _json.inn(const Duration(hours: 2))},
          'Proof can be sent once a step has waited a day for Harbour '
              'Telecom.',
        ),
      ]) {
        testWidgets('a send refused as not due ($name) says why and stays', (
          tester,
        ) async {
          final run = refusedThenHeld(hold: false);
          final api = _Api({
            'GET /activations': (_) => _ok({
              'items': [run],
            }),
            'GET /activations/a_1': (_) => _ok(run),
            'POST /activations/a_1/proof': (_) => _notDue(details),
          });
          await pumpLiveLaunch(
            tester,
            proofPath('a_1'),
            api: api.client,
            mode: gated,
            overrides: [
              activationsServiceProvider.overrideWith(
                (ref) =>
                    _Uploads(ref.watch(accountLinkProvider)!, stepProof: true),
              ),
            ],
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('Record step 1.'), findsOneWidget);
          await _tap(tester, find.text('Choose a video'));
          await _tap(tester, _button('Send proof'));
          expect(api.to('POST /activations/a_1/proof'), hasLength(1));
          expect(find.byType(ProofScreen), findsOneWidget);
          expect(find.text(words), findsOneWidget);
        });
      }

      testWidgets('paid after a proof was turned down: the reward reads as '
          'the business\'s confirmation, not the proof\'s', (tester) async {
        final paid = _json.activationJson(
          confirmationMode: 'postback',
          progress: _json.runJson(
            status: 'paid',
            started: const Duration(days: 3),
            confirmedAt: [
              _json.at(const Duration(days: 1)),
              _json.at(Duration.zero),
            ],
            paidAt: _json.at(Duration.zero),
            proof: _json.proofJson(
              status: 'rejected',
              reason: 'The recording ends too soon.',
              step: 0,
            ),
          ),
        );
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [paid],
          }),
          'GET /activations/a_1': (_) => _ok(paid),
        });
        await pumpLiveLaunch(
          tester,
          activationPath('a_1'),
          api: api.client,
          mode: gated,
        );
        await tester.pumpAndSettle();
        expect(find.text('Your reward'), findsOneWidget);
        expect(find.text('Steps confirmed by Harbour Telecom'), findsOneWidget);
        expect(find.text('Proof received'), findsNothing);
      });

      for (final names in [false, true]) {
        testWidgets('Your proof of a step that pays nothing has no "Not '
            'credited yet?"; the last step\'s has it'
            '${names ? ', without iQLY\'s reply promise' : ''}', (
          tester,
        ) async {
          Map<String, Object?> proving(int step) => _json.activationJson(
            confirmationMode: 'proof',
            progress: _json.runJson(
              confirmedAt: [
                for (var i = 0; i < step; i++) _json.at(Duration.zero),
              ],
              proof: _json.proofJson(step: step),
            ),
          );
          var run = proving(0);
          final api = _Api({
            'GET /activations': (_) => _ok({
              'items': [run],
            }),
            'GET /activations/a_1': (_) => _ok(run),
          });
          final (container, _) = await pumpLiveLaunch(
            tester,
            activationPath('a_1'),
            api: api.client,
            mode: Backend.of({
              ...gated.live,
              LiveFeature.support,
              if (names) LiveFeature.helpAuthorNames,
            }),
          );
          await tester.pumpAndSettle();
          expect(find.text('Checking with Harbour Telecom'), findsWidgets);
          await tester.scrollUntilVisible(find.text('Ask for help'), 100);
          expect(find.text('Not credited yet?'), findsNothing);
          expect(find.textContaining('Support usually replies'), findsNothing);

          run = proving(2);
          await container.read(activationsProvider.notifier).refresh('a_1');
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text('Ask for help'), 100);
          expect(find.text('Not credited yet?'), findsOneWidget);
          expect(
            find.textContaining('Support usually replies'),
            names ? findsNothing : findsOneWidget,
          );
          await _tap(tester, find.text('Ask for help'));
          expect(
            _button(names ? 'Send to Harbour Telecom' : 'Send to support'),
            findsOneWidget,
          );
          expect(
            find.text('We reply here and by notification.'),
            names ? findsNothing : findsOneWidget,
          );
          expect(
            find.text(
              'Usually replies within an hour on weekdays, within a day at '
              'weekends.',
            ),
            names ? findsNothing : findsOneWidget,
          );
        });
      }
    });

    testWidgets('a full activation: "Couldn\'t start." and Start goes grey', (
      tester,
    ) async {
      var full = false;
      final api = _Api({
        'POST /activations/a_1/start': (_) {
          full = true;
          return _no(409, 'ACTIVATION_FULL');
        },
        'GET /activations/a_1': (_) =>
            _ok(_json.activationJson(spotsLeft: full ? 0 : 498)),
      });
      await pumpLiveLaunch(
        tester,
        activationPath('a_1'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      await _tap(tester, _button('Start activation'));
      expect(find.text("Couldn't start."), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(
        tester.widget<IqButton>(_button('Start activation')).disabled,
        isTrue,
      );
    });

    testWidgets('no answer to Start offers Try again', (tester) async {
      final api = _Api();
      await pumpLiveLaunch(
        tester,
        activationPath('a_1'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      api.offline = true;
      await _tap(tester, _button('Start activation'));
      expect(
        find.text("Couldn't start. Check your connection."),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('under 18 opens Date of birth', (tester) async {
      final api = _Api({
        'POST /activations/a_1/start': (_) => _no(403, 'UNDER_AGE'),
      });
      await pumpLiveLaunch(
        tester,
        activationPath('a_1'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      await _tap(tester, _button('Start activation'));
      expect(find.byType(EditDetailScreen), findsOneWidget);
      expect(find.text('Date of birth'), findsWidgets);
    });

    testWidgets('an activation from a link joins the list from the API', (
      tester,
    ) async {
      final api = _Api({
        'GET /activations/a_7': (_) => _ok(
          _json.activationJson(
            id: 'a_7',
            title: 'Top up ₦500 with the Harbour app',
            status: 'paused',
          ),
        ),
      });
      final (container, _) = await pumpLiveLaunch(
        tester,
        activationPath('a_7'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      expect(find.text('Top up ₦500 with the Harbour app'), findsOneWidget);
      expect(api.to('GET /activations/a_7'), hasLength(1));

      await container.read(activationsProvider.notifier).refreshQuietly();
      await tester.pumpAndSettle();
      expect(api.to('GET /activations').length, greaterThan(1));
      expect(
        find.text('Top up ₦500 with the Harbour app'),
        findsOneWidget,
        reason: 'a fresh list without it keeps the open screen',
      );
    });

    group('a sent proof the API turns down', () {
      /// The proof page of a run past its window, a recording up, and Send
      /// proof answered with [answer].
      Future<_Api> send(
        WidgetTester tester,
        http.Response Function() answer, {
        Map<String, Object?>? reread,
      }) async {
        final stuck = _json.activationJson(
          progress: _json.runJson(
            confirmedAt: [_json.at(const Duration(hours: 24, minutes: 20))],
          ),
        );
        var sent = false;
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [stuck],
          }),
          'GET /activations/a_1': (_) => _ok(sent ? reread ?? stuck : stuck),
          'POST /activations/a_1/proof': (_) {
            sent = true;
            return answer();
          },
        });
        await pumpLiveLaunch(
          tester,
          proofPath('a_1'),
          api: api.client,
          mode: _on,
          overrides: [
            activationsServiceProvider.overrideWith(
              (ref) => _Uploads(ref.watch(accountLinkProvider)!),
            ),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProofScreen), findsOneWidget);
        await _tap(tester, find.text('Choose a video'));
        await _tap(tester, _button('Send proof'));
        expect(api.to('POST /activations/a_1/proof'), hasLength(1));
        return api;
      }

      testWidgets('one already waiting: back to where the activation stands', (
        tester,
      ) async {
        final api = await send(
          tester,
          () => _no(409, 'ACTIVATION_PROOF_PENDING'),
          reread: _json.activationJson(
            progress: _json.runJson(
              confirmedAt: [_json.at(const Duration(days: 1))],
              proof: _json.proofJson(),
            ),
          ),
        );
        expect(api.to('GET /activations/a_1').length, greaterThan(1));
        expect(find.byType(ProofScreen), findsNothing);
        expect(find.byType(ActivationScreen), findsOneWidget);
        expect(find.text('Your proof'), findsWidgets);
      });

      testWidgets('a field it will not take: "Couldn\'t send.", no Try again', (
        tester,
      ) async {
        await send(tester, () => _no(400, 'VALIDATION_ERROR'));
        expect(find.byType(ProofScreen), findsOneWidget);
        expect(find.text("Couldn't send."), findsOneWidget);
        expect(find.text('Try again'), findsNothing);
      });

      testWidgets('a throttle offers Try again', (tester) async {
        await send(tester, () => _no(429, 'RATE_LIMITED'));
        expect(
          find.text("Couldn't send. Check your connection."),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);
      });

      testWidgets('closed meanwhile: ended, nothing left to send', (
        tester,
      ) async {
        final api = await send(
          tester,
          () => _no(409, 'ACTIVATION_CLOSED'),
          reread: _json.activationJson(
            status: 'closed',
            progress: _json.runJson(
              status: 'expired',
              confirmedAt: [_json.at(const Duration(hours: 24, minutes: 20))],
              expiredAt: _json.at(const Duration(minutes: 1)),
            ),
          ),
        );
        expect(api.to('GET /activations/a_1').length, greaterThan(1));
        expect(_button('This activation has ended'), findsOneWidget);
        expect(_button('Send proof'), findsNothing);
        expect(find.text('Choose a video'), findsNothing);
        expect(find.textContaining("Couldn't send"), findsNothing);
      });
    });

    for (final onSend in [true, false]) {
      testWidgets('paid meanwhile (${onSend ? 'send' : 'upload'}): back to '
          'the reward, not "ended"', (tester) async {
        final stuck = _json.activationJson(
          progress: _json.runJson(
            confirmedAt: [_json.at(const Duration(hours: 24, minutes: 20))],
          ),
        );
        final credited = _json.activationJson(
          progress: _json.runJson(
            status: 'paid',
            confirmedAt: [for (var i = 0; i < 3; i++) _json.at(Duration.zero)],
            paidAt: _json.at(Duration.zero),
          ),
        );
        var paid = false;
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [stuck],
          }),
          'GET /activations/a_1': (_) => _ok(paid ? credited : stuck),
          'POST /activations/a_1/proof': (_) {
            paid = true;
            return _no(409, 'ACTIVATION_COMPLETION_PAID');
          },
        });
        await pumpLiveLaunch(
          tester,
          proofPath('a_1'),
          api: api.client,
          mode: _on,
          overrides: [
            activationsServiceProvider.overrideWith(
              (ref) => _Uploads(
                ref.watch(accountLinkProvider)!,
                refusal: onSend
                    ? null
                    : const ApiRefused(409, 'ACTIVATION_COMPLETION_PAID'),
              ),
            ),
          ],
        );
        await tester.pumpAndSettle();
        if (!onSend) paid = true;
        await _tap(tester, find.text('Choose a video'));
        if (onSend) await _tap(tester, _button('Send proof'));
        await tester.pumpAndSettle();
        expect(find.byType(ProofScreen), findsNothing);
        expect(find.byType(ActivationScreen), findsOneWidget);
        expect(find.text('Your reward'), findsOneWidget);
        expect(find.text('This activation has ended'), findsNothing);
      });
    }

    testWidgets('an upload refused as closed ends the page; no Retry loop', (
      tester,
    ) async {
      final stuck = _json.activationJson(
        progress: _json.runJson(
          confirmedAt: [_json.at(const Duration(hours: 24, minutes: 20))],
        ),
      );
      final api = _Api({
        'GET /activations': (_) => _ok({
          'items': [stuck],
        }),
        'GET /activations/a_1': (_) => _ok(stuck),
      });
      await pumpLiveLaunch(
        tester,
        proofPath('a_1'),
        api: api.client,
        mode: _on,
        overrides: [
          activationsServiceProvider.overrideWith(
            (ref) => _Uploads(
              ref.watch(accountLinkProvider)!,
              refusal: const ApiRefused(409, 'ACTIVATION_CLOSED'),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      final reads = api.to('GET /activations/a_1').length;
      await _tap(tester, find.text('Choose a video'));
      expect(api.to('GET /activations/a_1').length, reads + 1);
      expect(_button('This activation has ended'), findsOneWidget);
      expect(_button('Send proof'), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('an upload refused as closing goes to Restore', (tester) async {
      final stuck = _json.activationJson(
        progress: _json.runJson(
          confirmedAt: [_json.at(const Duration(hours: 24, minutes: 20))],
        ),
      );
      final api = _Api({
        'GET /activations': (_) => _ok({
          'items': [stuck],
        }),
        'GET /activations/a_1': (_) => _ok(stuck),
      });
      final (_, router) = await pumpLiveLaunch(
        tester,
        proofPath('a_1'),
        api: api.client,
        mode: _on,
        overrides: [
          activationsServiceProvider.overrideWith(
            (ref) => _Uploads(
              ref.watch(accountLinkProvider)!,
              refusal: const ApiRefused(403, 'ACCOUNT_CLOSING'),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Choose a video'));
      expect(_at(router), Routes.restoreAccount);
    });

    testWidgets('a proof turned down after the close offers no Record again', (
      tester,
    ) async {
      final ended = _json.activationJson(
        status: 'closed',
        progress: _json.runJson(
          status: 'expired',
          confirmedAt: [_json.at(const Duration(days: 1))],
          expiredAt: _json.at(const Duration(hours: 1)),
          proof: _json.proofJson(status: 'rejected', reason: 'Too short.'),
        ),
      );
      final api = _Api({
        'GET /activations': (_) => _ok({
          'items': [ended],
        }),
        'GET /activations/a_1': (_) => _ok(ended),
      });
      await pumpLiveLaunch(
        tester,
        activationPath('a_1'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      expect(find.text('Proof not accepted. Too short.'), findsOneWidget);
      expect(find.text('Record again'), findsNothing);
      expect(_button('This activation has ended'), findsOneWidget);
    });

    testWidgets('a proof turned down while open still offers Record again', (
      tester,
    ) async {
      final open = _json.activationJson(
        progress: _json.runJson(
          confirmedAt: [_json.at(const Duration(days: 1))],
          proof: _json.proofJson(status: 'rejected', reason: 'Too short.'),
        ),
      );
      final api = _Api({
        'GET /activations': (_) => _ok({
          'items': [open],
        }),
        'GET /activations/a_1': (_) => _ok(open),
      });
      await pumpLiveLaunch(
        tester,
        activationPath('a_1'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      expect(find.text('Record again'), findsOneWidget);
      expect(_button('This activation has ended'), findsNothing);
    });

    for (final support in [false, true]) {
      testWidgets('Ask for help on a proof '
          '${support ? 'shows with support live' : 'hides without support'}', (
        tester,
      ) async {
        final checking = _json.activationJson(
          progress: _json.runJson(
            confirmedAt: [_json.at(const Duration(days: 1))],
            proof: _json.proofJson(),
          ),
        );
        final api = _Api({
          'GET /activations': (_) => _ok({
            'items': [checking],
          }),
          'GET /activations/a_1': (_) => _ok(checking),
        });
        await pumpLiveLaunch(
          tester,
          activationPath('a_1'),
          api: api.client,
          mode: support ? Backend.of({..._on.live, LiveFeature.support}) : _on,
        );
        await tester.pumpAndSettle();
        expect(find.text('Checking with Harbour Telecom'), findsWidgets);
        expect(
          find.text('Ask for help'),
          support ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Not credited yet?'),
          support ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('a paused activation: the line says so and Start is off', (
      tester,
    ) async {
      final api = _Api({
        'GET /activations/a_1': (_) =>
            _ok(_json.activationJson(status: 'paused')),
      });
      await pumpLiveLaunch(
        tester,
        activationPath('a_1'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      expect(_button('This activation is paused'), findsOneWidget);
      expect(
        tester.widget<IqButton>(_button('This activation is paused')).disabled,
        isTrue,
      );
      expect(_button('Start activation'), findsNothing);
    });

    testWidgets('Start refused as paused: paused until a re-read says live', (
      tester,
    ) async {
      var status = 'live';
      final api = _Api({
        'POST /activations/a_1/start': (_) {
          status = 'paused';
          return _no(409, 'ACTIVATION_PAUSED');
        },
        'GET /activations': (_) => _ok({
          'items': [_json.activationJson(status: status)],
        }),
        'GET /activations/a_1': (_) =>
            _ok(_json.activationJson(status: status)),
      });
      final (container, _) = await pumpLiveLaunch(
        tester,
        activationPath('a_1'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      await _tap(tester, _button('Start activation'));
      expect(_button('This activation is paused'), findsOneWidget);
      expect(
        tester.widget<IqButton>(_button('This activation is paused')).disabled,
        isTrue,
      );
      expect(find.textContaining("Couldn't start"), findsNothing);

      // Resumed by the business; the next read (a resume, a push) says so.
      status = 'live';
      await container.read(activationsProvider.notifier).refreshQuietly();
      await tester.pumpAndSettle();
      expect(_button('This activation is paused'), findsNothing);
      expect(
        tester.widget<IqButton>(_button('Start activation')).disabled,
        isFalse,
      );
    });

    testWidgets('a paused flag the client kept clears on a live re-read', (
      tester,
    ) async {
      final api = _Api({
        'POST /activations/a_1/start': (_) => _no(409, 'ACTIVATION_PAUSED'),
        'GET /activations/a_1': (_) => _no(503, 'UNAVAILABLE'),
      });
      final (container, _) = await pumpLiveLaunch(
        tester,
        activationPath('a_1'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      await _tap(tester, _button('Start activation'));
      expect(_button('This activation is paused'), findsOneWidget);
      await container.read(activationsProvider.notifier).refreshQuietly();
      await tester.pumpAndSettle();
      expect(_button('Start activation'), findsOneWidget);
    });

    testWidgets('a link to an activation the API has not: it has ended', (
      tester,
    ) async {
      final api = _Api({
        'GET /activations/a_9': (_) => _no(404, 'ACTIVATION_NOT_FOUND'),
      });
      await pumpLiveLaunch(
        tester,
        activationPath('a_9'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      expect(find.text('This activation has ended'), findsOneWidget);
      expect(find.text('Find another activation'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      await _tap(tester, find.text('Find another activation'));
      expect(find.byType(ActivationsScreen), findsOneWidget);
    });

    testWidgets('a link opened offline: Try again brings it in', (
      tester,
    ) async {
      final api = _Api()..offline = true;
      await pumpLiveLaunch(
        tester,
        activationPath('a_1'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't load. Check your connection."),
        findsOneWidget,
      );
      api.offline = false;
      await _tap(tester, find.text('Try again'));
      expect(find.text(_plan), findsOneWidget);
      expect(_button('Start activation'), findsOneWidget);
    });

    testWidgets('Start throttled offers Try again', (tester) async {
      final api = _Api({
        'POST /activations/a_1/start': (_) => _no(429, 'RATE_LIMITED'),
      });
      await pumpLiveLaunch(
        tester,
        activationPath('a_1'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      await _tap(tester, _button('Start activation'));
      expect(
        find.text("Couldn't start. Check your connection."),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(
        tester.widget<IqButton>(_button('Start activation')).disabled,
        isFalse,
      );
    });

    testWidgets('Start refused as ended: Start goes off for good', (
      tester,
    ) async {
      final api = _Api({
        'POST /activations/a_1/start': (_) => _no(409, 'ACTIVATION_CLOSED'),
        'GET /activations/a_1': (_) => _no(503, 'UNAVAILABLE'),
      });
      await pumpLiveLaunch(
        tester,
        activationPath('a_1'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      await _tap(tester, _button('Start activation'));
      expect(find.text("Couldn't start."), findsOneWidget);
      expect(_button('This activation has ended'), findsOneWidget);
      expect(
        tester.widget<IqButton>(_button('This activation has ended')).disabled,
        isTrue,
      );
    });

    testWidgets('a throttled vote keeps the connection banner, no re-read', (
      tester,
    ) async {
      final api = _Api({
        'POST /polls/p_1/vote': (_) => _no(429, 'RATE_LIMITED'),
      });
      await pumpLiveLaunch(
        tester,
        pollsOf('org_sunline'),
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Zobo and ginger'));
      expect(
        find.text('Couldn’t send. Check your connection.'),
        findsOneWidget,
      );
      expect(api.to('GET /polls/p_1'), isEmpty);
    });

    testWidgets('a recording the API will not take is refused, not retried', (
      tester,
    ) async {
      final stuck = _json.activationJson(
        progress: _json.runJson(
          confirmedAt: [_json.at(const Duration(hours: 24, minutes: 20))],
        ),
      );
      final api = _Api({
        'GET /activations': (_) => _ok({
          'items': [stuck],
        }),
        'GET /activations/a_1': (_) => _ok(stuck),
      });
      await pumpLiveLaunch(
        tester,
        proofPath('a_1'),
        api: api.client,
        mode: _on,
        overrides: [
          activationsServiceProvider.overrideWith(
            (ref) => _Uploads(
              ref.watch(accountLinkProvider)!,
              refusal: const ApiRefused(413, 'FILE_TOO_LARGE'),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Choose a video'));
      expect(
        find.text(
          'Your video is 18 MB. Keep it under 50 MB and end on the '
          'Verification page.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an activation row in the feed opens the activation', (
      tester,
    ) async {
      final api = _Api({
        'GET /notifications': (_) => _ok({
          'items': [
            {
              'id': 'n_2',
              'type': 'activation_approved',
              'createdAt': _json.at(const Duration(minutes: 5)),
              'readAt': null,
              'title': '₦1,500.00 added to your wallet',
              'body':
                  '₦1,500.00 for the Harbour Telecom activation is in your '
                  'wallet now.',
              'amountKobo': 150000,
              'refs': {'activationId': 'a_1', 'ledgerId': 'l_9'},
            },
          ],
          'nextCursor': null,
          'unseen': 1,
        }),
      });
      await pumpLiveLaunch(
        tester,
        Routes.notifications,
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('₦1,500.00 added to your wallet'));
      expect(find.byType(ActivationScreen), findsOneWidget);
      expect(find.text(_plan), findsOneWidget);
    });

    testWidgets('My activations: the API’s runs under Active and Done', (
      tester,
    ) async {
      final api = _Api({
        'GET /activations': (_) => _ok({
          'items': [
            _json.activationJson(
              progress: _json.runJson(
                confirmedAt: [_json.at(const Duration(days: 1))],
                proof: _json.proofJson(),
              ),
            ),
          ],
        }),
        'GET /activations/mine': (_) => _ok({
          'items': [
            _json.activationJson(
              id: 'a_old',
              title: 'Cook a Sunline recipe and rate it',
              status: 'closed',
              progress: _json.runJson(
                status: 'expired',
                expiredAt: _json.at(const Duration(hours: 2)),
              ),
            ),
          ],
          'nextCursor': null,
        }),
      });
      await pumpLiveLaunch(
        tester,
        myActivationsPath,
        api: api.client,
        mode: _on,
      );
      await tester.pumpAndSettle();
      expect(find.byType(MyActivationsScreen), findsOneWidget);
      expect(find.text(_plan), findsOneWidget);
      expect(find.text('Cook a Sunline recipe and rate it'), findsNothing);
      await _tap(tester, find.text('Done'));
      expect(find.text('Cook a Sunline recipe and rate it'), findsOneWidget);
      expect(find.text(_plan), findsNothing);
    });

    testWidgets('an activation reward in the wallet names the business', (
      tester,
    ) async {
      final api = _Api({
        'GET /wallet': (_) => _ok(walletJson()),
        'GET /wallet/transactions': (_) => _ok({
          'items': [
            transactionJson({
              'id': 'l_9',
              'amount': 150000,
              'source': 'activation',
              'submissionId': null,
              'challengeId': null,
              'challengeTitle': null,
              'businessName': 'Harbour Telecom',
              'activationId': 'a_1',
              'note': _plan,
            }),
          ],
          'nextCursor': null,
        }),
      });
      await pumpLiveLaunch(tester, Routes.wallet, api: api.client, mode: _on);
      await tester.pumpAndSettle();
      expect(find.text('Harbour Telecom'), findsOneWidget);
      expect(find.text('Reward · $_plan'), findsOneWidget);
    });
  });

  group('polls and activations off (today’s staging)', () {
    testWidgets('nothing asks for them and every way in stays hidden', (
      tester,
    ) async {
      final api = _Api({
        'GET /notifications': (_) => _ok({
          'items': [
            {
              'id': 'n_1',
              'type': 'poll_new',
              'createdAt': _json.at(const Duration(minutes: 5)),
              'readAt': null,
              'title': 'Sunline Foods has a quick poll',
              'body': _flavour,
              'refs': {'pollId': 'p_1'},
            },
          ],
          'nextCursor': null,
          'unseen': 1,
        }),
      });
      final (container, router) = await pumpLiveLaunch(
        tester,
        Routes.home,
        api: api.client,
        mode: _off,
      );
      await tester.pumpAndSettle();
      expect(find.text('Quick polls'), findsNothing);
      expect(find.text('Activations'), findsNothing);
      expect(container.read(pollsServiceProvider), isA<PausedPollsService>());
      expect(container.read(pollsShownProvider), isFalse);
      expect(container.read(activationsShownProvider), isFalse);

      for (final hidden in [
        Routes.polls,
        pollsOf('org_sunline'),
        activationPath('a_1'),
        myActivationsPath,
      ]) {
        router.go(hidden);
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget, reason: hidden);
        expect(find.byType(PollsScreen), findsNothing);
        expect(find.byType(ActivationScreen), findsNothing);
      }

      router.go(Routes.notifications);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Sunline Foods has a quick poll'));
      expect(_at(router), Routes.notifications);

      router.go(Routes.more);
      await tester.pumpAndSettle();
      expect(find.text('Quick polls'), findsNothing);
      expect(find.text('Activations'), findsNothing);
      expect(
        api.paths.where(
          (p) => p.startsWith('/polls') || p.startsWith('/activations'),
        ),
        isEmpty,
      );
      final inputs = await surfaceInputs(container.read, launchNow);
      expect(inputs.showPolls, isFalse);
      expect(inputs.polls, isEmpty);
    });
  });

  group('the services each launch gets', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer launch(Backend mode, {ApiClient? api}) {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          liveModeProvider.overrideWithValue(mode),
          if (api != null) apiClientProvider.overrideWithValue(api),
          backendProvider.overrideWith(() => FixedBackend(mode)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('preview: the samples; live on: the API; live off: paused', () {
      final api = _Api().client;
      final preview = launch(Backend.preview);
      expect(preview.read(pollsServiceProvider), isA<DemoPollsService>());
      expect(
        preview.read(activationsServiceProvider),
        isA<DemoActivationsService>(),
      );
      expect(preview.read(pollsShownProvider), isTrue);
      expect(preview.read(activationsShownProvider), isTrue);

      final on = launch(_on, api: api);
      expect(on.read(pollsServiceProvider), isA<LivePollsService>());
      expect(
        on.read(activationsServiceProvider),
        isA<LiveActivationsService>(),
      );
      expect(on.read(pollsShownProvider), isTrue);
      expect(on.read(activationsShownProvider), isTrue);
      expect(hiddenRoute(on.read, Routes.polls), isFalse);
      expect(hiddenRoute(on.read, activationPath('a_1')), isFalse);

      final off = launch(_off, api: api);
      expect(off.read(pollsServiceProvider), isA<PausedPollsService>());
      expect(
        off.read(activationsServiceProvider),
        isA<PausedActivationsService>(),
      );
      expect(hiddenRoute(off.read, Routes.polls), isTrue);
      expect(hiddenRoute(off.read, activationPath('a_1')), isTrue);
    });

    test('activations need the wallet live with them', () {
      expect(
        Backend.of({LiveFeature.profile, LiveFeature.activations}).live,
        isNot(contains(LiveFeature.activations)),
      );
      expect(
        Backend.of({LiveFeature.profile, LiveFeature.polls}).live,
        contains(LiveFeature.polls),
      );
    });
  });
}
