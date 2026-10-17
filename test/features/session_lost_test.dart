import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';
import 'package:iqly_mobile/features/help/legal_screen.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/features/splash/splash_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/profile_harness.dart';

/// The real router at [location] on an API that answers every call 401,
/// with the session guard listening.
Future<(ProviderContainer, ApiClient, MemoryTokenStore)> _open(
  WidgetTester tester,
  String location, {
  bool signedIn = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  SharedPreferences.setMockInitialValues({
    if (signedIn) ...{
      ...signedInPrefs(),
      'session.name': 'Adaeze Okafor',
      'session.firstName': 'Adaeze',
      'onboarding.draft': jsonEncode({'state': 'Lagos'}),
      AccountDetailsNotifier.key: jsonEncode(
        const AccountDetails(phone: '+234 801 234 5678'),
      ),
      'submit.draft.c5': '{}',
    },
    SplashScreen.litKey: true,
    SavedBriefsNotifier.key: '[]',
  });
  final prefs = await SharedPreferences.getInstance();
  final tokens = MemoryTokenStore('abc.signed');
  final api = ApiClient(
    tokens: tokens,
    baseUrl: 'https://api.test',
    client: MockClient(
      (_) async => http.Response(
        jsonEncode({
          'success': false,
          'error': {'code': 'UNAUTHORIZED', 'message': 'Sign in again'},
        }),
        401,
      ),
    ),
  );
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      repositoryProvider.overrideWithValue(ScriptedRepository()),
      clockProvider.overrideWithValue(() => figmaNow),
      profileServiceProvider.overrideWithValue(TestProfileService()),
      apiClientProvider.overrideWithValue(api),
      routerProvider.overrideWithValue(router),
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
  return (container, api, tokens);
}

void main() {
  testWidgets('a 401 to the session token signs the phone out to the '
      'landing, as sign out does', (tester) async {
    final (container, api, tokens) = await _open(tester, Routes.terms);
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget);

    final res = await api.get('/me');
    await tester.pumpAndSettle();
    expect(res.code, 'UNAUTHORIZED');
    expect(find.byType(LandingScreen), findsOneWidget);
    final session = container.read(sessionProvider);
    expect(session.signedIn, isFalse);
    expect(session.onboardingDone, isFalse);
    expect(session.name, isNull);
    expect(await tokens.read(), isNull);
    final prefs = container.read(sharedPreferencesProvider);
    expect(prefs.getString(AccountDetailsNotifier.key), isNull);
    expect(prefs.getString('onboarding.draft'), isNull);
    expect(prefs.getString('submit.draft.c5'), isNull);
    expect(prefs.getString(SavedBriefsNotifier.key), '[]');
  });

  testWidgets('on the splash, the hand-off finds the session signed out', (
    tester,
  ) async {
    final (container, api, _) = await _open(tester, Routes.splash);
    await tester.pump();
    await api.get('/me');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(container.read(sessionProvider).signedIn, isFalse);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(LandingScreen), findsOneWidget);
  });

  testWidgets('signed out, a 401 only drops the token', (tester) async {
    final (container, api, tokens) = await _open(
      tester,
      Routes.signIn,
      signedIn: false,
    );
    await tester.pumpAndSettle();
    await api.get('/profiles/contributors/me');
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(await tokens.read(), isNull);
    expect(container.read(sessionProvider).signedIn, isFalse);
  });

  test('a preview build has no client, so nothing listens', () async {
    SharedPreferences.setMockInitialValues(signedInPrefs());
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    container.read(sessionGuardProvider);
    expect(container.read(apiClientProvider), isNull);
    expect(container.read(sessionProvider).signedIn, isTrue);
  });
}
