import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/live_auth.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/splash/splash_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/screens/app_harness.dart';
import 'live_api.dart';

/// Apple and Google never offer here.
class NoSocial implements SocialIdentity {
  @override
  bool offers(AuthProvider provider) => false;

  @override
  Future<SocialToken?> signIn(AuthProvider provider) async => null;

  @override
  Future<void> signOut() async {}
}

const livePreferences = {
  'closingSoon': true,
  'results': true,
  'payouts': true,
  'newBriefs': true,
  'polls': false,
};

/// The account's reads every live screen may make, and the sign out.
FakeApi accountApi([Map<String, ApiAnswer> more = const {}]) => FakeApi({
  'GET /me': (_) => answer(meJson()),
  'GET /profiles/contributors/me': (_) => answer(profileJson()),
  'GET /me/notification-preferences': (_) => answer(livePreferences),
  'GET /notifications': (_) =>
      answer({'items': <Object>[], 'nextCursor': null, 'unseen': 0}),
  'POST /auth/web/sign-out': (_) => raw({'success': true}),
  ...more,
});

/// Signed in as u_1 with first run done.
Map<String, Object> liveSignedIn([Map<String, Object> more = const {}]) => {
  ...signedInPrefs(),
  'session.userId': 'u_1',
  'session.name': 'Ada Obi',
  'session.firstName': 'Ada',
  SplashScreen.litKey: true,
  ...more,
};

/// The real router at [location] in a live build on [api] at 390 x 844,
/// animations off, the Figma clock.
Future<(ProviderContainer, GoRouter)> pumpLive(
  WidgetTester tester,
  String location,
  FakeApi api, {
  Map<String, Object>? prefs,
  LocalStore? store,
  Backend? mode,
  IqlyRepository? repository,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 54, bottom: 34);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  SharedPreferences.setMockInitialValues(prefs ?? liveSignedIn());
  final shared = await SharedPreferences.getInstance();
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(shared),
      repositoryProvider.overrideWithValue(repository ?? ScriptedRepository()),
      clockProvider.overrideWithValue(() => figmaNow),
      activationsServiceProvider.overrideWithValue(
        DemoActivationsService(
          clock: () => figmaNow,
          load: Duration.zero,
          delay: Duration.zero,
        ),
      ),
      routerProvider.overrideWithValue(router),
      authServiceProvider.overrideWithValue(
        LiveAuthService(api: api.client, social: NoSocial()),
      ),
      localStoreProvider.overrideWithValue(store ?? liveStore()),
      ...liveOverrides(api, mode: mode),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: buildTheme(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (container, router);
}

/// A store on the same clock as the outbox.
MemoryLocalStore liveStore() => MemoryLocalStore(clock: () => figmaNow);
