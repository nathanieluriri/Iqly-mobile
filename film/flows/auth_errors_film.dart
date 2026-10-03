import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/entry/entry_copy.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';
import 'package:iqly_mobile/ui/box_field.dart';
import 'package:iqly_mobile/ui/next_fab.dart';

import '../harness.dart';

/// Fresh install: a malformed email fails on the landing, the fixed one goes
/// on to Sign in, a wrong password fails there, and the right one lands on
/// Discover.
void main() {
  film('auth_errors', (d) async {
    await d.arrive(find.byType(LandingScreen), hold: 2);
    await d.tap(find.byType(IqBoxField), label: 'email-box');
    await d.hold(0.5);
    await d.type('adaeze@example');
    await d.hold(0.8);
    await d.tap(find.text('Continue'));
    await d.waitFor(find.text(EntryCopy.badEmail));
    expect(find.text(EntryCopy.badEmail), findsOneWidget);
    await d.hold(2);

    await d.type('.com');
    expect(find.text(EntryCopy.badEmail), findsNothing);
    await d.hold(0.8);
    await d.tap(find.text('Continue'));

    await d.arrive(find.byType(SignInScreen));
    await d.type('bold1234');
    await d.hold(0.8);
    await d.tap(find.byType(IqNextFab), label: 'next');
    final wrong = EntryCopy.signIn(AuthFailure.wrongCredentials);
    await d.waitFor(find.text(wrong));
    expect(find.text(wrong), findsOneWidget);
    await d.hold(2);

    await d.erase();
    expect(find.text(wrong), findsNothing);
    await d.hold(0.4);
    await d.type(DemoAuthService.password);
    await d.hold(0.8);
    await d.tap(find.byType(IqNextFab), label: 'next');

    await d.arrive(find.byType(HomeScreen));
    await d.waitFor(find.text('Closing soon'));
    await d.hold(2);
  });
}
