import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';

import '../harness.dart';
import '../steps.dart';

/// Fresh install, a returning contributor: the landing's Sign in link, the
/// email and password on Sign in, and Discover once its feed is in.
void main() {
  film('returning_sign_in', (d) async {
    await d.arrive(find.byType(LandingScreen), hold: 2);
    await d.tap(find.text('Sign in'), label: 'sign-in-link');

    await d.arrive(find.byType(SignInScreen));
    await d.type('adaeze@example.com');
    await d.hold(0.5);
    await d.submit();
    await d.hold(0.4);
    await d.type(DemoAuthService.password);
    await d.hold(0.8);
    await d.tap(button('Sign in'), label: 'sign-in');

    await onDiscover(d, hold: 2.5);
  });
}
