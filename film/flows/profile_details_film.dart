import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/more/more_screen.dart';
import 'package:iqly_mobile/features/profile/edit_detail_screen.dart';
import 'package:iqly_mobile/features/profile/your_details_screen.dart';
import 'package:iqly_mobile/ui/dock.dart';

import '../harness.dart';

const _returning = <String, Object>{
  'session.signedIn': true,
  'session.onboardingDone': true,
  'session.firstTipSeen': true,
};

/// A returning contributor changes their phone number from More: Your
/// details, Edit · Phone number, Save, the 6-digit code, Confirm, and back
/// on Your details with the new number.
void main() {
  film('profile_details', prefs: _returning, (d) async {
    await d.waitFor(find.byType(HomeScreen));
    await d.waitFor(find.text('Closing soon'));
    await d.settle(on: find.byType(HomeScreen));
    await d.hold(1.5);

    await d.tap(
      find.descendant(of: find.byType(IqDock), matching: find.text('More')),
      label: 'more-tab',
    );
    await d.waitFor(find.text('Your details'));
    await d.settle(on: find.byType(MoreScreen));
    await d.hold(2);

    await d.tap(find.text('Your details').last);
    await d.arrive(find.byType(YourDetailsScreen), hold: 1.8);

    await d.tap(find.text('Phone number'));
    await d.hold(1);
    await d.tap(find.byType(EditableText), label: 'phone');
    await d.hold(0.5);
    await d.erase(4);
    await d.hold(0.3);
    await d.type('1111');
    await d.hold(1.2);

    await d.tap(find.text('Save'));
    await d.arrive(find.byType(PhoneCodeScreen), hold: 1);
    await d.type('482152');
    await d.hold(1);
    await d.tap(find.text('Confirm'));
    await d.gone(find.byType(PhoneCodeScreen));
    await d.settle(on: find.byType(YourDetailsScreen));
    await d.hold(2);
  });
}
