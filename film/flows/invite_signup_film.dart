import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/password_screen.dart';
import 'package:iqly_mobile/features/entry/your_name_screen.dart';
import 'package:iqly_mobile/features/onboarding/welcome_screen.dart';
import 'package:iqly_mobile/ui/box_field.dart';

import '../harness.dart';
import '../steps.dart';

/// A friend's invite link opens the app on the landing; sign up shows
/// "Invited by Chidi A." with the code added, and the new account lands on
/// Welcome.
void main() {
  film('invite_signup', link: '/invite/CHIDI7', (d) async {
    await d.arrive(find.byType(LandingScreen), hold: 2);
    await d.tap(find.byType(IqBoxField), label: 'email-box');
    await d.hold(0.4);
    await d.type('tolu.bello@example.com');
    await d.hold(0.6);
    await d.tap(button('Continue'), label: 'continue');

    await d.arrive(find.byType(YourNameScreen), hold: 1.5);
    expect(find.text('Invited by Chidi A. · code CHIDI7 added'), findsOne);
    await d.type('Tolu');
    await d.hold(0.3);
    await d.submit();
    await d.hold(0.3);
    await d.type('Bello');
    await d.hold(0.6);
    await d.tap(button('Continue'), label: 'continue');

    await d.arrive(find.byType(PasswordScreen));
    await d.type('Lagos2026!');
    await d.hold(0.6);
    await d.tap(button('Create account'), label: 'create-account');

    await d.arrive(find.byType(WelcomeScreen), hold: 2.5);
  });
}
