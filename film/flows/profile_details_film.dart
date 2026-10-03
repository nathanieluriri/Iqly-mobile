import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/profile/profile_screen.dart';
import 'package:iqly_mobile/features/profile/your_details_screen.dart';
import 'package:iqly_mobile/ui/dock.dart';
import 'package:iqly_mobile/ui/field.dart';

import '../harness.dart';

const _returning = <String, Object>{
  'session.signedIn': true,
  'session.onboardingDone': true,
  'session.firstTipSeen': true,
};

/// A returning contributor edits Your details from Profile: a new phone
/// number, another state and city, then Save changes back to Profile.
void main() {
  film('profile_details', prefs: _returning, (d) async {
    await d.waitFor(find.byType(HomeScreen));
    await d.waitFor(find.text('Closing soon'));
    await d.settle(on: find.byType(HomeScreen));
    await d.hold(1.5);

    await d.tap(
      find.descendant(of: find.byType(IqDock), matching: find.text('Profile')),
      label: 'profile-tab',
    );
    await d.waitFor(find.text('Your details'));
    await d.settle(on: find.byType(ProfileScreen));
    await d.hold(2);

    await d.tap(find.text('Your details'));
    await d.arrive(find.byType(YourDetailsScreen), hold: 1.8);

    await d.tap(
      find.byWidgetPredicate((w) => w is IqField && w.label == 'Phone number'),
      label: 'phone',
    );
    await d.hold(0.5);
    await d.erase(4);
    await d.hold(0.3);
    await d.type('1111');
    await d.waitFor(find.text(YourDetailsScreen.readyText));
    await d.hold(1.2);

    final form = find
        .descendant(
          of: find.byType(YourDetailsScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    final residence = find.text('STATE OF RESIDENCE');
    await d.reveal(residence, form);
    await d.hold(0.6);
    await d.tap(residence);
    await d.pickFromSheet('Ogun');
    await d.waitFor(find.text('Select city'));
    await d.settle(on: find.byType(YourDetailsScreen));
    await d.hold(1);

    final city = find.text('CITY');
    await d.reveal(city, form);
    await d.hold(0.6);
    await d.tap(city);
    await d.waitFor(find.text('Abeokuta'));
    await d.hold(0.8);
    await d.tap(find.text('Abeokuta'));
    await d.hold(0.8);
    await d.tap(find.text('Use this'));
    await d.gone(find.text('Use this'));
    await d.waitFor(find.text(YourDetailsScreen.readyText));
    await d.hold(1.5);

    await d.tap(find.text('Save changes'));
    await d.gone(find.byType(YourDetailsScreen));
    await d.settle(on: find.byType(ProfileScreen));
    await d.hold(2);
  });
}
