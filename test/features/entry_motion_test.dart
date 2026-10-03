import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/app.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real app from the landing; the landing's line art loops, so the
/// normal boot pumps a while instead of settling.
Future<void> _boot(WidgetTester tester, {required bool reduced}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = buildRouter(initialLocation: Routes.landing);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routerProvider.overrideWithValue(router),
      ],
      child: const IqlyApp(),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  expect(find.byType(LandingScreen), findsOneWidget);
}

double _dx(WidgetTester tester, Type screen) =>
    tester.getTopLeft(find.byType(screen)).dx;

void main() {
  testWidgets('Sign in pushes in from the landing: mid-slide at half time', (
    tester,
  ) async {
    await _boot(tester, reduced: false);
    await tester.tap(find.text('Sign in'));
    // The route's first frame lays out offstage for heroes.
    await tester.pump();
    await tester.pump();
    expect(_dx(tester, SignInScreen), closeTo(IqTravel.screen, 0.01));

    await tester.pump(IqDurations.screen ~/ 2);
    final mid = _dx(tester, SignInScreen);
    expect(
      mid,
      closeTo(IqTravel.screen * (1 - IqCurves.easeOut.transform(0.5)), 0.5),
    );
    expect(mid, inExclusiveRange(0, IqTravel.screen));
    expect(
      _dx(tester, LandingScreen),
      closeTo(-IqTravel.screen * IqCurves.easeIn.transform(0.5), 0.5),
    );

    await tester.pump(IqDurations.screen ~/ 2);
    expect(_dx(tester, SignInScreen), 0);
  });

  testWidgets('reduced motion: Sign in arrives in place, no in-between slide', (
    tester,
  ) async {
    await _boot(tester, reduced: true);
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump();
    final seen = <double>[_dx(tester, SignInScreen)];
    for (var i = 0; i < 3; i++) {
      await tester.pump(IqDurations.crossfade ~/ 3);
      seen.add(_dx(tester, SignInScreen));
      expect(_dx(tester, LandingScreen), 0);
    }
    expect(seen, everyElement(0));
    await tester.pumpAndSettle();
    expect(find.byType(LandingScreen), findsNothing);
    expect(_dx(tester, SignInScreen), 0);
  });
}
