import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/entry/forgot_password_screen.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/reset_link_sent_screen.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';

import '../harness.dart';

/// Fresh install: from the landing's sign in link to a reset link, and back
/// to Sign in.
void main() {
  film('forgot_password', (d) async {
    await d.arrive(find.byType(LandingScreen), hold: 2);
    await d.tap(find.text('Sign in'));

    await d.arrive(find.byType(SignInScreen));
    await d.tap(find.text('Forgot your password?'));

    await d.arrive(find.byType(ForgotPasswordScreen));
    await d.type('adaeze@example.com');
    await d.hold(0.8);
    await d.tap(find.text('Send reset link'));

    await d.arrive(find.byType(ResetLinkSentScreen), hold: 2.5);
    await d.tap(find.text('Sign in'));

    await d.arrive(find.byType(SignInScreen), hold: 2);
  });
}
