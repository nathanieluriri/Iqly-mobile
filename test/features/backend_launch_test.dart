import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/app.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/app_version.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/more/try_notifications_screen.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/features/splash/splash_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/discover_harness.dart';
import '../golden/screens/more_harness.dart';

const _ms = Duration(milliseconds: 1);

/// After its first light-up the splash hands off 1300 in (Dark 300,
/// crossfade 400, hold 600).
const _handoff = Duration(milliseconds: 1300);

class _Health implements HealthService {
  _Health(this.answer);

  final Future<HealthReport> answer;

  @override
  Future<HealthReport> check() => answer;
}

class _SlowVersions implements AppVersionService {
  _SlowVersions(this.answer);

  final Future<AppRelease> answer;

  @override
  Future<AppRelease> check() => answer;
}

const _ready = HealthReport(
  ready: true,
  contract: 1,
  features: {...LiveFeature.values},
);

/// The mode Try notifications shows, as set.
class _Fixed extends BackendNotifier {
  _Fixed(this.mode, this.at);

  final Backend mode;
  final DateTime? at;

  @override
  Backend build() => mode;

  @override
  DateTime? get checkedAt => at;
}

/// Launches the real app on the splash of a build on the API, signed out,
/// with a saved brief left by a preview launch.
Future<ProviderContainer> _launch(
  WidgetTester tester,
  HealthService health, {
  AppVersionService versions = const DemoAppVersionService(),
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 54, bottom: 34);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    SplashScreen.litKey: true,
    SavedBriefsNotifier.key: jsonEncode([]),
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      repositoryProvider.overrideWithValue(ScriptedRepository()),
      clockProvider.overrideWithValue(() => figmaNow),
      activationsServiceProvider.overrideWithValue(
        DemoActivationsService(
          clock: () => figmaNow,
          load: Duration.zero,
          delay: Duration.zero,
        ),
      ),
      ...discoverOverrides(),
      appVersionServiceProvider.overrideWithValue(versions),
      healthServiceProvider.overrideWithValue(health),
      backendProvider.overrideWith(
        () => LiveBackendNotifier(forgetPreview: forgetPreviewRecords),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const IqlyApp()),
  );
  return container;
}

Future<void> _toLanding(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_ms * 500);
  await tester.pump();
}

void main() {
  group('the splash and the health check', () {
    testWidgets('an answer before the hand-off decides the launch, with no '
        'hold', (tester) async {
      final container = await _launch(tester, _Health(Future.value(_ready)));
      await tester.pump();
      await tester.pump(_handoff);
      await _toLanding(tester);
      expect(find.byType(LandingScreen), findsOneWidget);
      expect(container.read(backendProvider), Backend(_ready.features));
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString(SavedBriefsNotifier.key), isNull);
      expect(
        prefs.getStringList(LiveBackendNotifier.launchedKey),
        LiveFeature.values.map((f) => f.name).toList(),
      );
    });

    testWidgets('no answer holds the splash 2 s at most, then the launch runs '
        'on what was kept, whatever comes later', (tester) async {
      final answer = Completer<HealthReport>();
      final container = await _launch(tester, _Health(answer.future));
      await tester.pump();
      await tester.pump(_handoff);
      await tester.pump(_ms * 1999);
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pump(_ms);
      await _toLanding(tester);
      expect(find.byType(LandingScreen), findsOneWidget);
      expect(container.read(backendProvider), Backend.preview);

      answer.complete(_ready);
      await tester.pump();
      expect(container.read(backendProvider), Backend.preview);
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getStringList(LiveBackendNotifier.launchedKey), isEmpty);
      expect(
        prefs.getStringList(LiveBackendNotifier.decidedKey),
        hasLength(LiveFeature.values.length),
      );
    });

    testWidgets('with both checks slow the hold is still 2 s', (tester) async {
      await _launch(
        tester,
        _Health(Completer<HealthReport>().future),
        versions: _SlowVersions(Completer<AppRelease>().future),
      );
      await tester.pump();
      await tester.pump(_handoff);
      await tester.pump(_ms * 1999);
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pump(_ms);
      await _toLanding(tester);
      expect(find.byType(LandingScreen), findsOneWidget);
    });

    testWidgets('an answer during the hold decides the launch and opens the '
        'app at once', (tester) async {
      final answer = Completer<HealthReport>();
      final container = await _launch(tester, _Health(answer.future));
      await tester.pump();
      await tester.pump(_handoff);
      await tester.pump(_ms * 500);
      expect(find.byType(SplashScreen), findsOneWidget);
      answer.complete(_ready);
      await tester.pump();
      await _toLanding(tester);
      expect(find.byType(LandingScreen), findsOneWidget);
      expect(container.read(backendProvider), Backend(_ready.features));
    });
  });

  group('Try notifications', () {
    Future<void> showRow(
      WidgetTester tester,
      Backend mode,
      DateTime? at,
    ) async {
      await pumpMore(
        tester,
        Routes.tryNotifications,
        overrides: [backendProvider.overrideWith(() => _Fixed(mode, at))],
      );
      await tester.scrollUntilVisible(
        find.text(mode.isPreview ? 'Preview' : 'Live'),
        200,
      );
    }

    testWidgets('names a live launch and when health last answered', (
      tester,
    ) async {
      await showRow(
        tester,
        const Backend({LiveFeature.notifications, LiveFeature.profile}),
        DateTime(2026, 10, 17, 9, 41),
      );
      expect(find.text('Live'), findsOneWidget);
      expect(
        find.text('profile, notifications. Health checked 17 Oct, 09:41.'),
        findsOneWidget,
      );
    });

    testWidgets('says preview, and when health never answered', (tester) async {
      await showRow(tester, Backend.preview, null);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Health not checked yet.'), findsOneWidget);
    });

    test('the line reads the same for any order of features', () {
      expect(
        TryNotificationsScreen.backendLine(
          const Backend({LiveFeature.wallet, LiveFeature.briefs}),
          DateTime(2026, 1, 2, 3, 4),
        ),
        'briefs, wallet. Health checked 2 Jan, 03:04.',
      );
    });
  });
}
