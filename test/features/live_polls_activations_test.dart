import 'dart:convert';

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
  _Uploads(super.link, {this.refusal});

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

    testWidgets('Start refused as paused shows the paused state', (
      tester,
    ) async {
      final api = _Api({
        'POST /activations/a_1/start': (_) => _no(409, 'ACTIVATION_PAUSED'),
      });
      await pumpLiveLaunch(
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
