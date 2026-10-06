import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/app.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/onboarding/welcome_screen.dart';
import 'package:iqly_mobile/features/splash/splash_mark.dart';
import 'package:iqly_mobile/features/splash/splash_screen.dart';
import 'package:iqly_mobile/ui/brand_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ms = Duration(milliseconds: 1);
const _size = Size(390, 844);
const _top = 54.0;

double _eio(double t) => IqCurves.easeInOut.transform(t);

Future<SharedPreferences> _launch(
  WidgetTester tester, {
  bool lit = false,
  bool signedIn = false,
  bool reduced = false,
}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: _top, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: _top, bottom: 34);
  addTearDown(tester.view.reset);
  if (reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  SharedPreferences.setMockInitialValues({
    if (lit) SplashScreen.litKey: true,
    if (signedIn) 'session.signedIn': true,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        repositoryProvider.overrideWithValue(DemoRepository(DemoData())),
      ],
      child: const IqlyApp(),
    ),
  );
  return prefs;
}

/// How far the progress has filled.
double _progress(WidgetTester tester) => tester
    .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
    .widthFactor!;

/// The centre of the mark's tile.
Offset _tile(WidgetTester tester) => tester.getCenter(find.byType(SplashMark));

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

/// The status bar style the app asks for: the top annotation under the
/// status bar, as the engine reads it.
SystemUiOverlayStyle? _statusBar(WidgetTester tester) => tester
    .binding
    .renderViews
    .first
    .debugLayer!
    .find<SystemUiOverlayStyle>(const Offset(195, _top));

void main() {
  group('first launch: the Figma light-up (spec 6.1)', () {
    testWidgets('the progress reads 32, 92 and 120 of 120 at each phase', (
      tester,
    ) async {
      await _launch(tester);
      await tester.pump();
      expect(_tile(tester), const Offset(195, 422));
      expect(_progress(tester), 0);
      await tester.pump(_ms * 800);
      expect(_progress(tester), closeTo(32 / 120, 0.0001));
      expect(_tile(tester).dy, closeTo(844 * 400 / 844, 0.01));
      await tester.pump(_ms * 1100);
      expect(_progress(tester), closeTo(92 / 120, 0.0001));
      await tester.pump(_ms * 1100);
      expect(_progress(tester), 1);
      expect(
        _opacityAbove(tester, find.byType(FractionallySizedBox)),
        closeTo(0, 0.001),
      );
    });

    testWidgets('halfway into Spark the mark has eased halfway', (
      tester,
    ) async {
      await _launch(tester);
      await tester.pump();
      await tester.pump(_ms * 550);
      expect(_progress(tester), closeTo(32 / 120 * _eio(0.5), 0.0001));
      expect(_tile(tester).dy, closeTo(422 + (400 - 422) * _eio(0.5), 0.01));
    });

    testWidgets(
      'signed out: the wordmark lands on the landing logo, the status bar '
      'turns dark 200 into the hand-off, the landing takes over at 400',
      (tester) async {
        final prefs = await _launch(tester);
        await tester.pump();
        await tester.pump(_ms * 3600);
        expect(prefs.getBool(SplashScreen.litKey), isTrue);
        expect(_statusBar(tester), SystemUiOverlayStyle.light);
        await tester.pump(_ms * 150);
        expect(_statusBar(tester), SystemUiOverlayStyle.light);
        await tester.pump(_ms * 100);
        expect(_statusBar(tester), SystemUiOverlayStyle.dark);
        await tester.pump(_ms * 150);
        final logos = find.byType(IqBrandLogo);
        final splashLogo = tester.getRect(logos.last);
        expect(splashLogo.width, closeTo(LandingScreen.logoWidth, 0.5));
        expect(splashLogo.top, closeTo(_top + LandingScreen.logoTop, 0.5));

        await tester.pump(_ms);
        await tester.pump();
        await tester.pump();
        expect(find.byType(LandingScreen), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        final landingLogo = tester.getRect(find.byType(IqBrandLogo));
        expect(landingLogo.left, closeTo(splashLogo.left, 0.5));
        expect(landingLogo.top, closeTo(splashLogo.top, 0.5));
        expect(landingLogo.width, closeTo(splashLogo.width, 0.5));
        expect(_opacityAbove(tester, find.byType(IqBrandLogo)), 1);
      },
    );
  });

  testWidgets('a later launch crossfades Dark to Settled in place', (
    tester,
  ) async {
    await _launch(tester, lit: true);
    await tester.pump();
    final start = _tile(tester);
    await tester.pump(_ms * 500);
    expect(_tile(tester), start);
    final tile = find.ancestor(
      of: find.byType(SplashMark),
      matching: find.byType(Opacity),
    );
    expect(
      tester.widget<Opacity>(tile.first).opacity,
      closeTo(1 - _eio(0.5), 0.001),
    );
    await tester.pump(_ms * 800);
    await tester.pump(_ms * 400);
    expect(find.byType(LandingScreen), findsNothing);
    await tester.pump(_ms);
    await tester.pump();
    await tester.pump();
    expect(find.byType(LandingScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('reduced motion: nothing travels, then a dissolve', (
    tester,
  ) async {
    await _launch(tester, reduced: true);
    await tester.pump();
    final start = _tile(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(_ms * 200);
      expect(_tile(tester), start);
    }
    await tester.pump(_ms * 200);
    await tester.pump();
    expect(find.byType(LandingScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets(
    'signed in mid first run: Welcome dissolves in 400 under a light status '
    'bar until 200 in',
    (tester) async {
      await _launch(tester, lit: true, signedIn: true);
      await tester.pump();
      await tester.pump(_ms * 1300);
      await tester.pump();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      await tester.pump(_ms * 100);
      expect(_statusBar(tester), SystemUiOverlayStyle.light);
      final welcome = _opacityAbove(tester, find.byType(WelcomeScreen));
      expect(welcome, inExclusiveRange(0, 1));
      await tester.pump(_ms * 150);
      expect(_statusBar(tester), SystemUiOverlayStyle.dark);
      await tester.pump(_ms * 200);
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
      expect(_statusBar(tester), SystemUiOverlayStyle.dark);
    },
  );
}
