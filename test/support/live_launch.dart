import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/live_auth.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/live/live_data_fixtures.dart' show FixedBackend;
import 'live_app.dart' show NoSocial;

final launchNow = DateTime(2026, 10, 17, 10);

/// Signed in as u_1 (Ada Obi) with first run done.
Map<String, Object> signedInLive([Map<String, Object> more = const {}]) => {
  'session.signedIn': true,
  'session.onboardingDone': true,
  'session.firstTipSeen': true,
  'session.userId': 'u_1',
  'session.name': 'Ada Obi',
  'session.firstName': 'Ada',
  'splash.lit': true,
  ...more,
};

/// The real router at [location] on a live build as main.dart wires one:
/// the app's own live repository and services on [api], a launch fixed to
/// [mode] (everything live by default), main.dart's retry, 390 x 844 with
/// animations off.
Future<(ProviderContainer, GoRouter)> pumpLiveLaunch(
  WidgetTester tester,
  String location, {
  required ApiClient api,
  LocalStore? store,
  Map<String, Object>? prefs,
  Backend? mode,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  SharedPreferences.setMockInitialValues(prefs ?? signedInLive());
  final shared = await SharedPreferences.getInstance();
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  final container = ProviderContainer(
    retry: retryUnlessPaused,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(shared),
      clockProvider.overrideWithValue(() => launchNow),
      routerProvider.overrideWithValue(router),
      apiClientProvider.overrideWithValue(api),
      localStoreProvider.overrideWithValue(
        store ?? MemoryLocalStore(clock: () => launchNow),
      ),
      backendProvider.overrideWith(
        () => FixedBackend(mode ?? Backend.of(LiveFeature.values)),
      ),
      authServiceProvider.overrideWithValue(
        LiveAuthService(api: api, social: NoSocial()),
      ),
      demoRepositoryProvider.overrideWithValue(
        DemoRepository(DemoData(now: launchNow)),
      ),
      activationsServiceProvider.overrideWithValue(
        DemoActivationsService(
          clock: () => launchNow,
          load: Duration.zero,
          delay: Duration.zero,
        ),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  container.read(sessionGuardProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: buildTheme(), routerConfig: router),
    ),
  );
  return (container, router);
}
