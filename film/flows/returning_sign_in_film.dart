import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';
import 'package:iqly_mobile/ui/box_field.dart';
import 'package:iqly_mobile/ui/next_fab.dart';

import '../harness.dart';

/// Fresh install, known email: the landing hands over to Sign in with the
/// email filled, and the password lands on Discover.
void main() {
  film('returning_sign_in', (d) async {
    await d.arrive(find.byType(LandingScreen), hold: 2);
    await d.tap(find.byType(IqBoxField), label: 'email-box');
    await d.hold(0.5);
    await d.type('adaeze@example.com');
    await d.hold(0.8);
    await d.tap(find.text('Continue'));

    await d.arrive(find.byType(SignInScreen));
    await d.type(DemoAuthService.password);
    await d.hold(0.8);
    await d.tap(find.byType(IqNextFab), label: 'next');

    await d.arrive(find.byType(HomeScreen));
    await d.waitFor(find.text('Closing soon'));
    await d.hold(2);
  });
}
