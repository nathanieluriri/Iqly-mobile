import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/features/profile/account_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/live_api.dart';

final _now = DateTime(2026, 10, 17, 10);

class _Health implements HealthService {
  _Health(this.report);

  final HealthReport report;

  @override
  Future<HealthReport> check() async => report;
}

/// Ada's writes from an earlier live launch, queued while offline: a
/// profile edit and a read mark.
Future<MemoryLocalStore> _queued() async {
  final store = MemoryLocalStore(clock: () => _now);
  await store.enqueue(
    'u_1',
    kind: AccountWrite.profile.kind,
    payload: {'phone': '+2348031234567'},
    coalesceKey: AccountWrite.profile.coalesceKey,
  );
  await store.enqueue(
    'u_1',
    kind: AccountWrite.read.kind,
    payload: {
      'ids': ['n_1'],
    },
    coalesceKey: AccountWrite.read.coalesceKey,
  );
  return store;
}

FakeApi _api() => FakeApi({
  'PATCH /profiles/contributors/me': (_) => answer(profileJson()),
  'POST /notifications/read': (_) => answer({'read': 1}),
});

/// A launch signed in as Ada whose mode [backend] decides, the account's
/// writes running as main.dart runs them.
Future<ProviderContainer> _launch(
  FakeApi api,
  LocalStore store,
  BackendNotifier Function() backend, {
  Map<String, Object> prefs = const {},
  HealthService? health,
}) async {
  SharedPreferences.setMockInitialValues({
    'session.signedIn': true,
    'session.onboardingDone': true,
    'session.userId': 'u_1',
    ...prefs,
  });
  final shared = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(shared),
      clockProvider.overrideWithValue(() => _now),
      localStoreProvider.overrideWithValue(store),
      apiClientProvider.overrideWithValue(api.client),
      backendProvider.overrideWith(backend),
      if (health != null) healthServiceProvider.overrideWithValue(health),
    ],
  );
  addTearDown(c.dispose);
  startAccountSync(c);
  await pumpEventQueue();
  await c.read(outboxProvider).kick();
  return c;
}

List<String> _sent(FakeApi api) => [for (final call in api.calls) call.route];

Future<Map<String, OutboxStatus>> _left(LocalStore store) async => {
  for (final item in await store.outbox('u_1')) item.kind: item.status,
};

/// Which launches send the account's queued writes (contract 2 and 8): a
/// preview launch sends none, a live one only those of the features it
/// runs, and only once the splash has fixed its mode. The rest wait, kept
/// and not failed, for a launch that runs them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a preview launch sends nothing and keeps every write', () async {
    final api = _api();
    final store = await _queued();
    await _launch(api, store, () => FixedBackend(Backend.preview));
    expect(_sent(api), isEmpty);
    expect(await _left(store), {
      AccountWrite.profile.kind: OutboxStatus.pending,
      AccountWrite.read.kind: OutboxStatus.pending,
    });
  });

  test('a live launch that pauses the profile sends the read mark and keeps '
      'the profile edit for the next launch that runs the profile', () async {
    final api = _api();
    final store = await _queued();
    final paused = await _launch(
      api,
      store,
      () => FixedBackend(Backend.of(const {LiveFeature.notifications})),
    );
    expect(_sent(api), ['POST /notifications/read']);
    expect(await _left(store), {
      AccountWrite.profile.kind: OutboxStatus.pending,
    });
    final waiting = (await store.outbox('u_1')).single;
    expect(waiting.failures, 0);
    expect(waiting.lastErrorCode, isNull);
    paused.dispose();

    await _launch(api, store, () => FixedBackend(allLive));
    expect(_sent(api), [
      'POST /notifications/read',
      'PATCH /profiles/contributors/me',
    ]);
    expect(await _left(store), isEmpty);
  });

  test('a first live launch, which starts as preview, sends once the splash '
      'has checked health and fixed the mode', () async {
    final api = _api();
    final store = await _queued();
    final c = await _launch(
      api,
      store,
      () => LiveBackendNotifier(forgetPreview: (_) async {}),
      health: _Health(
        HealthReport(
          ready: true,
          contract: Backend.contract,
          features: LiveFeature.values.toSet(),
        ),
      ),
    );
    expect(c.read(backendProvider).isPreview, isTrue);
    expect(_sent(api), isEmpty);

    await c.read(backendProvider.notifier).check();
    await c.read(backendProvider.notifier).lock();
    await pumpEventQueue();
    await c.read(outboxProvider).kick();
    expect(_sent(api), [
      'PATCH /profiles/contributors/me',
      'POST /notifications/read',
    ]);
    expect(await _left(store), isEmpty);
  });

  test('a live launch sends nothing until the splash fixes its mode', () async {
    final api = _api();
    final store = await _queued();
    final c = await _launch(
      api,
      store,
      () => LiveBackendNotifier(forgetPreview: (_) async {}),
      prefs: {
        LiveBackendNotifier.decidedKey: [
          for (final feature in firstFeatures) feature.name,
        ],
      },
    );
    expect(c.read(backendProvider), allLive);
    expect(_sent(api), isEmpty);

    await c.read(backendProvider.notifier).lock();
    await pumpEventQueue();
    await c.read(outboxProvider).kick();
    expect(_sent(api), [
      'PATCH /profiles/contributors/me',
      'POST /notifications/read',
    ]);
    expect(await _left(store), isEmpty);
  });
}
