import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/responsive.dart';
import 'package:iqly_mobile/router.dart';

import 'entry_harness.dart';

const _keyboard = 336.0;

/// How much the screen's content area shrinks when a keyboard is up.
Future<double> _shrinkUnderKeyboard(WidgetTester tester) async {
  final content = find.byType(CenteredContent).first;
  final before = tester.getSize(content).height;
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
  await tester.pump();
  final shrink = before - tester.getSize(content).height;
  await tester.pump(const Duration(seconds: 1));
  return shrink;
}

void main() {
  for (final route in [
    Routes.onboarding,
    Routes.onboardingResume,
    Routes.onboardingAboutYou,
    Routes.resetLinkSent,
    Routes.notificationsAsk,
    Routes.home,
    Routes.submissions,
  ]) {
    testWidgets('$route holds its layout while a keyboard leaves', (
      tester,
    ) async {
      await bootApp(
        tester,
        prefs: {
          'session.signedIn': true,
          'session.onboardingDone': true,
          'session.firstTipSeen': true,
        },
        start: route,
      );
      expect(await _shrinkUnderKeyboard(tester), 0);
    });
  }

  testWidgets('a screen with fields makes room for the keyboard', (
    tester,
  ) async {
    await bootApp(tester, start: Routes.yourName);
    expect(await _shrinkUnderKeyboard(tester), greaterThan(_keyboard - 40));
  });
}
