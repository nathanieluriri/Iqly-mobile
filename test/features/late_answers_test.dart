import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/drafts_data.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/live_auth.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/data/wallet_service.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/profile/account_sync.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/features/settings/settings_state.dart';
import 'package:iqly_mobile/features/wallet/wallet_state.dart';
import 'package:iqly_mobile/surfaces/surfaces.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/live/live_data_fixtures.dart';
import '../support/live_app.dart' show NoSocial;

final _now = DateTime(2026, 10, 17, 10);

/// Ada (u_1) and Bob (u_2) on the API, each answered as the token the
/// request carries. Ada's requests to the routes [holds] names wait until
/// [release], as on a slow network.
class _Api {
  final tokens = MemoryTokenStore('ada.token');
  bool Function(String route) holds = (_) => false;
  final _held = Completer<void>();

  late final client = ApiClient(
    tokens: tokens,
    baseUrl: 'https://api.test',
    client: MockClient(_answer),
  );

  void release() => _held.complete();

  Future<http.Response> _answer(http.Request request) async {
    final route = '${request.method} ${request.url.path}';
    if (route == 'POST /auth/web/sign-in/email') {
      return http.Response(
        jsonEncode({
          'redirect': false,
          'token': 'raw',
          'user': {'id': 'u_2', 'name': 'Bob Ade', 'email': 'bob@x.com'},
        }),
        200,
        headers: {
          'content-type': 'application/json',
          'set-auth-token': 'bob.token',
        },
      );
    }
    if (route == 'POST /auth/web/sign-out') return ok({'success': true});
    final who = switch (request.headers['authorization']) {
      'Bearer ada.token' => 'ada',
      'Bearer bob.token' => 'bob',
      _ => null,
    };
    if (who == null) return refused(401, 'UNAUTHORIZED');
    if (who == 'ada' && holds(route)) await _held.future;
    final bob = who == 'bob';
    return switch (route) {
      'GET /me' => ok({
        'id': bob ? 'u_2' : 'u_1',
        'name': bob ? 'Bob Ade' : 'Ada Obi',
        'email': bob ? 'bob@x.com' : 'ada@x.com',
        'status': 'active',
        'profile': null,
      }),
      'GET /wallet' => ok(
        walletJson({
          'contributorId': bob ? 'u_2' : 'u_1',
          'available': bob ? 0 : 2000000,
          'pendingWithdrawals': 0,
          'withdrawable': bob ? 0 : 2000000,
          'totalEarned': bob ? 0 : 3000000,
        }),
      ),
      'GET /wallet/transactions' => ok(page(bob ? [] : [transactionJson()])),
      'GET /wallet/withdrawals' => ok(page(bob ? [] : [withdrawalJson()])),
      'GET /wallet/withdrawals/w_1' when !bob => ok(
        withdrawalJson({
          'status': 'completed',
          'completedAt': '2026-10-17T09:00:00.000Z',
        }),
      ),
      'GET /wallet/bank-account' => ok(
        bob ? null : bankAccountJson({'accountName': 'ADA OBI'}),
      ),
      'GET /banks' => ok(banksJson),
      'GET /challenges/browse' => ok({
        'items': [
          challengeJson({'id': bob ? 'c_bob' : 'c_ada'}),
        ],
        'page': 1,
        'pageCount': 1,
      }),
      'GET /me/notification-preferences' => ok({
        'closingSoon': true,
        'results': true,
        'payouts': true,
        'newBriefs': true,
        'polls': false,
      }),
      'PUT /me/notification-preferences' => ok(jsonDecode(request.body)),
      _ => refused(404, 'NOT_FOUND'),
    };
  }
}

/// A live launch signed in as Ada, the outbox and the session guard running
/// as main.dart runs them.
Future<ProviderContainer> _adaSignedIn(_Api api, MemoryLocalStore store) async {
  SharedPreferences.setMockInitialValues({
    'session.signedIn': true,
    'session.onboardingDone': true,
    'session.firstTipSeen': true,
    'session.userId': 'u_1',
    'session.name': 'Ada Obi',
  });
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    retry: retryUnlessPaused,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => _now),
      apiClientProvider.overrideWithValue(api.client),
      localStoreProvider.overrideWithValue(store),
      backendProvider.overrideWith(() => FixedBackend(allLive)),
      authServiceProvider.overrideWithValue(
        LiveAuthService(api: api.client, social: NoSocial()),
      ),
      demoRepositoryProvider.overrideWithValue(DemoRepository(DemoData())),
    ],
  );
  addTearDown(c.dispose);
  c
    ..read(sessionGuardProvider)
    ..read(accountSyncProvider);
  return c;
}

/// Ada signs out, the phone forgetting her as Sign out does, and Bob signs
/// in, as completeSignIn records a returning account.
Future<void> _adaOutBobIn(ProviderContainer c) async {
  final auth = c.read(authServiceProvider);
  await auth.signOut();
  await forgetSession(c.read);
  final result = await auth.signIn(email: 'bob@x.com', password: 'secret123');
  expect(result.userId, 'u_2');
  final session = c.read(sessionProvider.notifier);
  await session.setUserId(result.userId);
  await session.setSignedIn(true);
  await session.setName(result.name);
  await session.setOnboardingDone(true);
  await pumpEventQueue();
}

/// Keeps what it is started and published with, instead of touching the
/// phone's surfaces.
class _Surfaces extends Surfaces {
  _Surfaces()
    : super(
        router: GoRouter(
          routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
        ),
        signedIn: () => true,
        tabRoots: const {'/'},
      );

  final published = <SurfaceInputs>[];

  @override
  Future<void> start(SurfaceInputs inputs) async {}

  @override
  Future<bool> publish(SurfaceInputs inputs) async {
    published.add(inputs);
    return true;
  }
}

/// Answers that set out for Ada and land once Bob is signed in on the same
/// phone: none of them shows for Bob, and none is kept on the phone.
void main() {
  test('Ada\'s quiet wallet reload lands in no one\'s wallet and keeps '
      'nothing of hers on the phone', () async {
    final api = _Api();
    final store = MemoryLocalStore(clock: () => _now);
    final c = await _adaSignedIn(api, store);
    final sub = c.listen(walletProvider, (_, _) {});
    addTearDown(sub.close);
    final ada = await c.read(walletProvider.future);
    expect(ada.savedBank?.accountName, 'ADA OBI');

    api.holds = (route) => route.startsWith('GET /wallet');
    final reload = c.read(walletProvider.notifier).refreshQuietly();
    await pumpEventQueue();
    await _adaOutBobIn(c);
    final bob = await c.read(walletProvider.future);
    expect(bob.savedBank, isNull);
    expect(bob.totals.withdrawableKobo, 0);

    api.release();
    await reload;
    await pumpEventQueue();
    final shown = c.read(walletProvider).value!;
    expect(shown.savedBank, isNull);
    expect(shown.totals.withdrawableKobo, 0);
    expect(shown.activity, isEmpty);
    expect(await store.readCache('u_1', LiveCacheKeys.wallet), isNull);
    expect(await store.readCache('u_1', LiveCacheKeys.bankAccount), isNull);
  });

  test('a switch of Ada\'s the outbox sends lands after her sign out without '
      'putting her preferences back on the phone', () async {
    final api = _Api();
    final store = MemoryLocalStore(clock: () => _now);
    final c = await _adaSignedIn(api, store);
    await c.read(notificationPreferencesProvider.future);
    api.holds = (route) => route == 'PUT /me/notification-preferences';
    expect(
      await c
          .read(notificationPreferencesProvider.notifier)
          .set(NotificationTopic.results, false),
      isTrue,
    );
    await pumpEventQueue();
    await _adaOutBobIn(c);
    expect(await store.readCache('u_1', AccountKeys.preferences), isNull);

    api.release();
    await pumpEventQueue();
    expect(await store.readCache('u_1', AccountKeys.preferences), isNull);
    final bobs = await c.read(notificationPreferencesProvider.future);
    expect(bobs[NotificationTopic.results], isTrue);
  });

  test('Ada\'s pull to refresh leaves Bob\'s feed as his own', () async {
    final api = _Api();
    final c = await _adaSignedIn(api, MemoryLocalStore(clock: () => _now));
    final sub = c.listen(discoverFeedProvider, (_, _) {});
    addTearDown(sub.close);
    final ada = await c.read(discoverFeedProvider.future);
    expect([for (final b in ada.briefs) b.id], ['c_ada']);

    api.holds = (route) => route == 'GET /challenges/browse';
    final refresh = c.read(discoverFeedProvider.notifier).refresh();
    await pumpEventQueue();
    await _adaOutBobIn(c);
    final bob = await c.read(discoverFeedProvider.future);
    expect([for (final b in bob.briefs) b.id], ['c_bob']);

    api.release();
    await refresh;
    await pumpEventQueue();
    final shown = c.read(discoverFeedProvider).value!;
    expect([for (final b in shown.briefs) b.id], ['c_bob']);
    expect(shown.refresh, RefreshPhase.idle);
  });

  test('the tracker stops following Ada\'s withdrawal once she is signed '
      'out, and passes on nothing it hears after', () async {
    final api = _Api();
    final c = await _adaSignedIn(api, MemoryLocalStore(clock: () => _now));
    final sub = c.listen(walletProvider, (_, _) {});
    addTearDown(sub.close);
    final withdrawal = (await c.read(walletProvider.future)).withdrawals.single;
    expect(withdrawal.onHold, isTrue);

    api.holds = (route) => route == 'GET /wallet/withdrawals/w_1';
    final heard = <Withdrawal>[];
    final ended = Completer<void>();
    final following = c
        .read(walletServiceProvider)
        .watch(withdrawal)
        .listen(heard.add, onDone: ended.complete);
    addTearDown(following.cancel);
    await pumpEventQueue();
    expect(heard, hasLength(1));
    await _adaOutBobIn(c);

    api.release();
    await pumpEventQueue();
    expect(heard, hasLength(1));
    expect(ended.isCompleted, isTrue);
  });

  test('home surfaces read for Ada are not published once Bob is signed '
      'in', () async {
    final api = _Api();
    final store = MemoryLocalStore(clock: () => _now);
    await store.saveDraft(
      'u_1',
      Draft(briefId: 'c_ada', title: 'Ada\'s draft', editedAt: _now),
    );
    final c = await _adaSignedIn(api, store);
    api.holds = (route) => route == 'GET /challenges/browse';
    final surfaces = _Surfaces();
    await startSurfaces(surfaces, c);
    await pumpEventQueue();
    await _adaOutBobIn(c);
    expect([for (final b in surfaces.published.last.briefs) b.id], ['c_bob']);

    api.release();
    await pumpEventQueue();
    final last = surfaces.published.last;
    expect([for (final b in last.briefs) b.id], ['c_bob']);
    expect(last.draftBriefId, isNull);
  });
}
