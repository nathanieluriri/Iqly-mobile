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
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/drafts_data.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/surfaces/surfaces.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/live/live_data_fixtures.dart'
    show FixedBackend, challengeJson, firstFeatures;

final _now = DateTime(2026, 10, 17, 10);

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

  SurfaceInputs? started;
  final published = <SurfaceInputs>[];

  @override
  Future<void> start(SurfaceInputs inputs) async => started = inputs;

  @override
  Future<bool> publish(SurfaceInputs inputs) async {
    published.add(inputs);
    return true;
  }
}

Future<ProviderContainer> _container(
  Future<http.Response> Function(http.Request r) answer, {
  Backend? mode,
}) async {
  SharedPreferences.setMockInitialValues({
    'session.signedIn': true,
    'session.userId': 'u_1',
  });
  final prefs = await SharedPreferences.getInstance();
  final store = MemoryLocalStore(clock: () => _now);
  await store.writeCache('u_1', LiveCacheKeys.briefs, [challengeJson()]);
  await store.saveDraft(
    'u_1',
    Draft(briefId: 'c_1', title: 'Sunday', editedAt: _now),
  );
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => _now),
      apiClientProvider.overrideWithValue(
        ApiClient(
          tokens: MemoryTokenStore('t'),
          baseUrl: 'https://api.test',
          client: MockClient(answer),
        ),
      ),
      localStoreProvider.overrideWithValue(store),
      backendProvider.overrideWith(
        () => FixedBackend(mode ?? Backend.of(firstFeatures)),
      ),
      demoRepositoryProvider.overrideWithValue(DemoRepository(DemoData())),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('a live launch on a network that does not answer starts the '
      'surfaces at once, on the phone\'s briefs and draft, so a launch link '
      'never waits; the API\'s answer is published when it comes', (
    tester,
  ) async {
    final c = await _container((_) => Completer<http.Response>().future);
    final surfaces = _Surfaces();
    unawaited(startSurfaces(surfaces, c));
    await tester.pump(const Duration(milliseconds: 1));
    expect(surfaces.started, isNotNull);
    expect([for (final b in surfaces.started!.briefs) b.id], ['c_1']);
    expect(surfaces.started!.draftBriefId, 'c_1');
    expect(surfaces.published, isEmpty);
    await tester.pump(const Duration(seconds: 21));
    expect(surfaces.published, hasLength(1));
  });

  testWidgets('the live answer replaces what the phone held', (tester) async {
    final c = await _container(
      (r) async => http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'items': [
              challengeJson({'id': 'c_2'}),
            ],
            'pageCount': 1,
          },
        }),
        200,
      ),
    );
    final surfaces = _Surfaces();
    await startSurfaces(surfaces, c);
    await tester.pump(const Duration(milliseconds: 10));
    expect([for (final b in surfaces.started!.briefs) b.id], ['c_1']);
    expect([for (final b in surfaces.published.single.briefs) b.id], ['c_2']);
  });

  testWidgets('a live launch that pauses briefs and submit shows none of '
      'the sample briefs and no sample draft', (tester) async {
    final c = await _container(
      (_) async => http.Response('{}', 404),
      mode: Backend.of(const {LiveFeature.profile}),
    );
    final surfaces = _Surfaces();
    await startSurfaces(surfaces, c);
    await tester.pump(const Duration(milliseconds: 10));
    for (final inputs in [surfaces.started!, ...surfaces.published]) {
      expect(inputs.briefs, isEmpty);
      expect(inputs.draftBriefId, isNull);
    }
  });

  testWidgets('a preview launch starts on the demo inputs, as before', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    final surfaces = _Surfaces();
    await startSurfaces(surfaces, c);
    final demo = SurfaceInputs.demo(_now);
    expect(
      [for (final b in surfaces.started!.briefs) b.id],
      [for (final b in demo.briefs) b.id],
    );
    expect(surfaces.started!.draftBriefId, demo.draftBriefId);
    expect(surfaces.published, isEmpty);
  });
}
