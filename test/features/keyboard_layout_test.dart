import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/responsive.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/dock.dart';

import '../golden/golden.dart' show loadAppFonts;
import 'entry_harness.dart';

const _keyboard = 336.0;

/// How much the screen's content area shrinks when a keyboard comes up as
/// iOS raises one: over the home indicator, whose padding it takes. The
/// Dock, when there is one, must not move.
Future<double> _shrinkUnderKeyboard(WidgetTester tester) async {
  tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 54, bottom: 34);
  await tester.pump();
  final content = find.byType(CenteredContent).first;
  final dock = find.byType(IqDock);
  final before = tester.getRect(content);
  final dockAt = dock.evaluate().isEmpty ? null : tester.getTopLeft(dock);
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
  tester.view.padding = const FakeViewPadding(top: 54);
  await tester.pump();
  final after = tester.getRect(content);
  if (dockAt != null) expect(tester.getTopLeft(dock), dockAt);
  await tester.pump(const Duration(seconds: 1));
  return before.height - after.height;
}

void main() {
  setUpAll(loadAppFonts);

  for (final route in [
    Routes.onboarding,
    Routes.onboardingResume,
    Routes.onboardingAboutYou,
    Routes.resetLinkSent,
    Routes.notificationsAsk,
    Routes.home,
    Routes.submissions,
    Routes.wallet,
    Routes.more,
    Routes.brief('c3'),
    Routes.notifications,
    Routes.polls,
    Routes.activations,
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
