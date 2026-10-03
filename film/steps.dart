import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';
import 'package:iqly_mobile/ui/box_field.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/next_fab.dart';
import 'package:iqly_mobile/ui/tip_card.dart';

import 'harness.dart';

/// returning_sign_in at a brisker pace: from the splash of a fresh install,
/// the known email on the landing and the password on Sign in, to Discover
/// once its feed is in.
Future<void> signIn(Director d) async {
  await d.arrive(find.byType(LandingScreen), hold: 0.8);
  await d.tap(find.byType(IqBoxField), label: 'email-box');
  await d.hold(0.3);
  await d.type('adaeze@example.com', cps: 16);
  await d.hold(0.4);
  await d.tap(find.text('Continue'));

  await d.arrive(find.byType(SignInScreen), hold: 0.5);
  await d.type(DemoAuthService.password, cps: 14);
  await d.hold(0.4);
  await d.tap(find.byType(IqNextFab), label: 'next');

  await d.waitFor(find.byType(HomeScreen));
  await d.waitFor(find.text('Closing soon'));
  await d.settle(on: find.byType(HomeScreen));
  await d.hold(1);
}

/// The first tip over Discover: waits for its card to finish arriving (it
/// follows the feed's own arrival), leaves it up to be read, dismisses it
/// and stays a second on the feed.
Future<void> readFirstTip(Director d) async {
  final ok = find.text('OK, got it');
  await d.waitFor(ok);
  final card = find
      .ancestor(
        of: find.byType(IqTipCard),
        matching: find.byType(FadeTransition),
      )
      .first;
  for (
    var i = 0;
    d.tester.widget<FadeTransition>(card).opacity.value < 1;
    i++
  ) {
    if (i == 180) {
      throw TestFailure('${d.name}: the first tip never arrived at ${d.time}s');
    }
    await d.frames(1);
  }
  await d.hold(1.2);
  await d.tap(ok);
  await d.gone(ok);
  await d.hold(1);
}

/// The close button of the sheet on top. Its semantics merge into the
/// sheet's own node ("Orchid Foods, Close"), so it is found by its icon.
Future<void> closeSheet(Director d) => d.tap(
  find.byWidgetPredicate((w) => w is IqIcon && w.icon == IqIcons.close),
  label: 'close',
);

/// The first vertical list inside [screen].
Finder listIn(Finder screen) => find
    .descendant(
      of: screen,
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    )
    .first;
