import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/features/entry/entry_copy.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';
import 'package:iqly_mobile/ui/banner.dart';
import 'package:iqly_mobile/ui/box_field.dart';

import '../harness.dart';
import '../steps.dart';

final _shown = find.byWidgetPredicate(
  (w) => w is IqBanner && w.visible,
  description: 'a shown banner',
);

/// Fresh install: a malformed email drops the banner on the landing, the
/// fixed one is already registered and offers Sign in with it filled, a
/// wrong password fails there, and the right one lands on Discover.
void main() {
  film('auth_errors', (d) async {
    await d.arrive(find.byType(LandingScreen), hold: 2);
    await d.tap(find.byType(IqBoxField), label: 'email-box');
    await d.hold(0.5);
    await d.type('adaeze@example');
    await d.hold(0.8);
    await d.tap(button('Continue'), label: 'continue');
    await d.waitFor(find.text(EntryCopy.badEmail));
    await d.hold(2);

    await d.type('.com');
    await d.gone(_shown);
    await d.hold(0.8);
    await d.tap(button('Continue'), label: 'continue');
    final signIn = find.descendant(
      of: find.byType(IqBanner),
      matching: find.text('Sign in'),
    );
    await d.waitFor(find.text(EntryCopy.emailRegistered));
    await d.hold(2);
    await d.tap(signIn, label: 'banner-sign-in');

    await d.arrive(find.byType(SignInScreen));
    await d.type('bold1234');
    await d.hold(0.8);
    await d.tap(button('Sign in'), label: 'sign-in');
    final wrong = EntryCopy.signIn(AuthFailure.wrongCredentials);
    await d.waitFor(find.text(wrong));
    await d.hold(2);

    await d.erase();
    await d.gone(_shown);
    await d.hold(0.4);
    await d.type(DemoAuthService.password);
    await d.hold(0.8);
    await d.tap(button('Sign in'), label: 'sign-in');

    await onDiscover(d, hold: 2);
  });
}
