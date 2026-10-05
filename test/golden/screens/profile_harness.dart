import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iqly_mobile/data/activations_service.dart';

import 'app_harness.dart';

/// The demo profile service answering at once, or failing when [fail] is
/// set, or holding saves until [release] when [hold] is set.
class TestProfileService extends DemoProfileService {
  TestProfileService() : super(delay: Duration.zero);

  bool fail = false;
  bool hold = false;
  int saves = 0;
  Completer<void>? _held;

  void release() => _held?.complete();

  @override
  Future<void> saveDetails(
    AccountDetails details,
    OnboardingProfile answers,
  ) async {
    if (hold) {
      final held = _held = Completer<void>();
      await held.future;
      _held = null;
    }
    if (fail) throw Exception('offline');
    saves++;
    await super.saveDetails(details, answers);
  }

  @override
  Future<void> setNotificationPreference(
    NotificationTopic topic,
    bool on,
  ) async {
    if (fail) throw Exception('offline');
    await super.setNotificationPreference(topic, on);
  }

  @override
  Future<void> deleteAccount() async {
    if (fail) throw Exception('offline');
    await super.deleteAccount();
  }
}

/// [pumpApp] with the profile service swapped for [service]: the real
/// router and shell at 390 x 844, OS insets, the Figma clock, animations
/// off unless [reducedMotion] is false. [settle] false stops after the
/// first frame, for motion tests.
Future<ProviderContainer> pumpProfileApp(
  WidgetTester tester,
  String location, {
  ProfileService? service,
  IqlyRepository? repository,
  Map<String, Object>? prefs,
  bool reducedMotion = true,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 54, bottom: 34);
  if (reducedMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs ?? signedInPrefs());
  final shared = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(shared),
      repositoryProvider.overrideWithValue(repository ?? ScriptedRepository()),
      activationsServiceProvider.overrideWithValue(
        DemoActivationsService(
          clock: () => figmaNow,
          load: Duration.zero,
          delay: Duration.zero,
        ),
      ),
      clockProvider.overrideWithValue(() => figmaNow),
      profileServiceProvider.overrideWithValue(service ?? TestProfileService()),
    ],
  );
  addTearDown(container.dispose);
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: buildTheme(),
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return container;
}
