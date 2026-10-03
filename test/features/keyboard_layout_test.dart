import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/next_fab.dart';

import 'entry_harness.dart';

const _keyboard = 336.0;

Future<double> _shiftUnderKeyboard(WidgetTester tester, Finder finder) async {
  final before = tester.getRect(finder).bottom;
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
  await tester.pump();
  final shift = before - tester.getRect(finder).bottom;
  await tester.pump(const Duration(seconds: 1));
  return shift;
}

void main() {
  for (final (route, action) in [
    (Routes.onboarding, 'Start'),
    (Routes.onboardingResume, 'Start over'),
    (Routes.onboardingAboutYou, 'Skip'),
    (Routes.resetLinkSent, 'Open email app'),
    (Routes.notificationsAsk, 'Not now'),
  ]) {
    testWidgets('$route holds its layout while a keyboard leaves', (
      tester,
    ) async {
      await bootApp(tester, prefs: {'session.signedIn': true}, start: route);
      expect(await _shiftUnderKeyboard(tester, find.text(action)), 0);
    });
  }

  testWidgets('a screen with fields keeps its next button above the keyboard', (
    tester,
  ) async {
    await bootApp(tester, start: Routes.yourName);
    expect(
      await _shiftUnderKeyboard(tester, find.byType(IqNextFab)),
      greaterThan(_keyboard - 40),
    );
  });
}
