import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/help_service.dart'
    show supportChannelsProvider;
import 'package:iqly_mobile/features/shell/tablet_frame.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 9:41 on the Figma status bar, a morning.
final figmaNow = DateTime(2026, 10, 3, 9, 41);

/// The demo dataset with the briefs call scripted per test: [calls] lists
/// what each successive call does (data, hang, fail, empty); the last entry
/// repeats.
class ScriptedRepository extends DemoRepository {
  ScriptedRepository([this.calls = const [BriefsCall.data]])
    : super(DemoData(now: figmaNow));

  final List<BriefsCall> calls;
  int _call = 0;

  @override
  Future<List<Brief>> briefs({BriefsLoad load = BriefsLoad.any}) {
    final step = calls[_call < calls.length ? _call : calls.length - 1];
    _call++;
    return switch (step) {
      BriefsCall.data => Future.value(data.briefs),
      BriefsCall.empty => Future.value(const []),
      BriefsCall.fail => Future.error(Exception('offline')),
      BriefsCall.hang => Completer<List<Brief>>().future,
    };
  }
}

enum BriefsCall { data, empty, fail, hang }

Map<String, Object> signedInPrefs({
  bool onboardingDone = true,
  bool firstTipSeen = true,
}) => {
  'session.signedIn': true,
  'session.onboardingDone': onboardingDone,
  'session.firstTipSeen': firstTipSeen,
};

/// Whether [overrides] already stand in for [provider] (an override names
/// its provider first).
bool _overrides(List<Override> overrides, Object provider) =>
    overrides.any((o) => o.toString().startsWith('$provider.'));

/// Pumps the real router at [location] at 390 x 844 with the OS insets,
/// animations off and the clock at [figmaNow] unless [clock] moves it. The
/// activations Discover shows answer at once unless [overrides] swap them;
/// [overrides] swap services (an instant wallet service, say). [settle]
/// false stops after the first frame, for motion tests. Returns the
/// container so a test can drive providers. The help screens are the ones
/// before the chat redesign unless [supportChannels].
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  String location, {
  IqlyRepository? repository,
  Map<String, Object>? prefs,
  bool reducedMotion = true,
  List<Override> overrides = const [],
  bool settle = true,
  DateTime Function()? clock,
  TransitionBuilder? builder,
  bool supportChannels = false,
  Size size = const Size(390, 844),
  FakeViewPadding insets = const FakeViewPadding(top: 54, bottom: 34),
  bool tabletFrame = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = insets;
  tester.view.viewPadding = insets;
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
      clockProvider.overrideWithValue(clock ?? () => figmaNow),
      if (!_overrides(overrides, activationsServiceProvider))
        activationsServiceProvider.overrideWithValue(
          DemoActivationsService(
            clock: clock ?? () => figmaNow,
            load: Duration.zero,
            delay: Duration.zero,
          ),
        ),
      if (!_overrides(overrides, supportChannelsProvider))
        supportChannelsProvider.overrideWithValue(supportChannels),
      ...overrides,
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
        builder: tabletFrame
            ? (context, child) => TabletFrame(
                router: router,
                child: builder?.call(context, child) ?? child!,
              )
            : builder,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return container;
}
