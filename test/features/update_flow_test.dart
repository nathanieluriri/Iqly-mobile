import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/app.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/core/updates.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/api_config.dart';
import 'package:iqly_mobile/data/app_version.dart';
import 'package:iqly_mobile/data/device.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/splash/splash_screen.dart';
import 'package:iqly_mobile/features/splash/update_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/brand_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/discover_harness.dart';

const _ms = Duration(milliseconds: 1);
final _download = Uri.parse(
  'https://staging.api.iqly.net/mobile/download/android',
);

final _required = AppRelease(
  installed: '0.1.0+1',
  status: UpdateStatus.required,
  minimum: '0.2.0',
  latest: '0.2.0+4',
  updateUrl: _download,
);

final _available = AppRelease(
  installed: '0.1.0+1',
  status: UpdateStatus.available,
  latest: '0.1.0+2',
  updateUrl: _download,
);

/// Answers once [answer] completes.
class _SlowService implements AppVersionService {
  _SlowService(this.answer);

  final Future<AppRelease> answer;

  @override
  Future<AppRelease> check() => answer;
}

/// Launches the real app on the splash, after its first light-up, so the
/// hand-off comes 1300 in (Dark 300, crossfade 400, hold 600).
Future<ProviderContainer> _launch(
  WidgetTester tester,
  AppVersionService versions, {
  bool signedIn = false,
  bool reduced = false,
  DemoDeviceService? device,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 54, bottom: 34);
  addTearDown(tester.view.reset);
  if (reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  SharedPreferences.setMockInitialValues({
    SplashScreen.litKey: true,
    if (signedIn) ...signedInPrefs(),
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
      if (device != null) deviceServiceProvider.overrideWithValue(device),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const IqlyApp()),
  );
  return container;
}

const _handoff = Duration(milliseconds: 1300);

Finder get _flyingLogo =>
    find.byWidgetPredicate((w) => w is IqBrandLogo && w.height == null);

Finder get _placedLogo => find.byWidgetPredicate(
  (w) => w is IqBrandLogo && w.height == UpdateScreen.logoHeight,
);

double _opacityAbove(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  for (final widget in tester.widgetList(
    find.ancestor(
      of: finder,
      matching: find.byWidgetPredicate(
        (w) => w is FadeTransition || w is Opacity,
      ),
    ),
  )) {
    opacity *= widget is FadeTransition
        ? widget.opacity.value
        : (widget as Opacity).opacity;
  }
  return opacity;
}

void main() {
  group('the splash hands over to Time to update', () {
    testWidgets('the logo glides into place, then the copy rises in', (
      tester,
    ) async {
      await _launch(tester, DemoAppVersionService(_required), signedIn: true);
      await tester.pump();
      await tester.pump(_handoff);
      await tester.pump();
      expect(find.byType(UpdateScreen), findsOneWidget);
      expect(
        tester.getRect(_flyingLogo),
        SplashScreen.wordmarkRect(const Size(390, 844)),
      );
      expect(_opacityAbove(tester, find.text(UpdateScreen.title)), 0);

      await tester.pump();
      await tester.pump(_ms * 150);
      final halfway = tester.getRect(_flyingLogo);
      expect(halfway.width, lessThan(210));
      expect(halfway.width, greaterThan(113));

      await tester.pump(_ms * 166);
      expect(_flyingLogo, findsNothing);
      expect(tester.getSize(_placedLogo).height, UpdateScreen.logoHeight);
      expect(_opacityAbove(tester, _placedLogo), 1);

      await tester.pump(_ms * 600);
      expect(_opacityAbove(tester, find.text(UpdateScreen.title)), 1);
      expect(find.text(UpdateScreen.reassurance), findsOneWidget);
      expect(find.text('YOU HAVE 0.1.0 · NEEDS 0.2.0'), findsOneWidget);
    });

    testWidgets('the splash holds for a slow answer', (tester) async {
      final answer = Completer<AppRelease>();
      await _launch(tester, _SlowService(answer.future));
      await tester.pump();
      await tester.pump(_handoff);
      await tester.pump(_ms * 1500);
      expect(find.byType(SplashScreen), findsOneWidget);
      answer.complete(_required);
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 900);
      expect(find.byType(UpdateScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('no answer within 2 s opens the app as usual', (tester) async {
      await _launch(tester, _SlowService(Completer<AppRelease>().future));
      await tester.pump();
      await tester.pump(_handoff);
      await tester.pump(_ms * 1999);
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pump(_ms);
      await tester.pump();
      await tester.pump(_ms * 500);
      await tester.pump();
      expect(find.byType(LandingScreen), findsOneWidget);
    });

    testWidgets('a late answer waits for the next screen change', (
      tester,
    ) async {
      final answer = Completer<AppRelease>();
      final container = await _launch(
        tester,
        _SlowService(answer.future),
        reduced: true,
      );
      await tester.pump();
      await tester.pump(_handoff);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LandingScreen), findsOneWidget);

      answer.complete(_required);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LandingScreen), findsOneWidget);
      expect(find.byType(UpdateScreen), findsNothing);

      container.read(routerProvider).go(Routes.signIn);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(UpdateScreen), findsOneWidget);
      expect(find.text(UpdateScreen.reassurance), findsNothing);
    });

    testWidgets('a current build opens the app as usual', (tester) async {
      await _launch(
        tester,
        const DemoAppVersionService(),
        signedIn: true,
        reduced: true,
      );
      await tester.pump();
      await tester.pump(_handoff);
      await tester.pumpAndSettle();
      expect(find.byType(UpdateScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('Time to update', () {
    testWidgets('Update iQLY opens the link, the line opens the web', (
      tester,
    ) async {
      final device = DemoDeviceService();
      await _launch(
        tester,
        DemoAppVersionService(_required),
        reduced: true,
        device: device,
      );
      await tester.pump();
      await tester.pump(_handoff);
      await tester.pumpAndSettle();

      await tester.tap(find.text(UpdateScreen.updateLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining("Can't update?"));
      await tester.pumpAndSettle();
      expect(device.opened, [_download, Uri.parse(ApiConfig.webUrl)]);
    });

    testWidgets('Back leaves the app', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _launch(tester, DemoAppVersionService(_required), reduced: true);
      await tester.pump();
      await tester.pump(_handoff);
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(calls, contains('SystemNavigator.pop'));
      expect(find.byType(UpdateScreen), findsOneWidget);
    });
  });

  group('Discover offers a newer build', () {
    Future<(ProviderContainer, DemoDeviceService)> pumpHome(
      WidgetTester tester, {
      bool firstTipSeen = true,
    }) async {
      final device = DemoDeviceService();
      final container = await pumpApp(
        tester,
        Routes.home,
        prefs: signedInPrefs(firstTipSeen: firstTipSeen),
        overrides: [
          ...discoverOverrides(),
          appVersionServiceProvider.overrideWithValue(
            DemoAppVersionService(_available),
          ),
          deviceServiceProvider.overrideWithValue(device),
        ],
      );
      await container.read(updatesProvider.notifier).check();
      await tester.pumpAndSettle();
      return (container, device);
    }

    testWidgets('once per version: Not now waits for the next one', (
      tester,
    ) async {
      final (container, device) = await pumpHome(tester);
      expect(find.text('A new version is available'), findsOneWidget);
      expect(
        find.text('Update iQLY to get the latest fixes and features.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('A new version is available'), findsNothing);
      expect(device.opened, isEmpty);
      expect(
        container
            .read(sharedPreferencesProvider)
            .getString(UpdatesNotifier.offeredKey),
        '0.1.0+2',
      );

      await container.read(updatesProvider.notifier).check();
      await tester.pumpAndSettle();
      expect(find.text('A new version is available'), findsNothing);
    });

    testWidgets('Update iQLY opens the download', (tester) async {
      final (_, device) = await pumpHome(tester);
      await tester.tap(find.text('Update iQLY'));
      await tester.pumpAndSettle();
      expect(device.opened, [_download]);
    });

    testWidgets('the first tip has its turn first', (tester) async {
      await pumpHome(tester, firstTipSeen: false);
      expect(find.text('A new version is available'), findsNothing);
    });
  });
}
