import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/onboarding/about_you_screen.dart';
import 'package:iqly_mobile/features/onboarding/welcome_screen.dart';

import '../harness.dart';

/// A new sign-up (signed in, nothing answered) skips first run from Welcome,
/// reads the first tip, then the setup nudge leads back to the first
/// unfinished step.
void main() {
  film('skip_for_now', prefs: {'session.signedIn': true}, (d) async {
    await d.arrive(find.byType(WelcomeScreen), hold: 2);
    await d.tap(find.text('Skip for now'));

    await d.arrive(find.byType(HomeScreen), hold: 2);
    await d.tap(find.text('OK, got it'));
    await d.hold(1.5);
    await d.tap(find.text('Finish setting up'));

    await d.arrive(find.byType(AboutYouScreen), hold: 2);
  });
}
