import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/more/more_screen.dart';
import 'package:iqly_mobile/features/profile/edit_detail_screen.dart';
import 'package:iqly_mobile/features/profile/profile_screen.dart';
import 'package:iqly_mobile/features/profile/your_details_screen.dart';
import 'package:iqly_mobile/ui/pressable.dart';

import '../harness.dart';
import '../steps.dart';

/// A returning contributor opens Your profile from the pass on More, then
/// Your details: a new phone number confirmed with its 6-digit code, the
/// occupation changed, an interest added, and back out to More.
void main() {
  film('profile_details', prefs: returning, (d) async {
    await onDiscover(d, hold: 1);
    await dockTab(d, 'More');
    await d.waitFor(find.text('Help centre'));
    await d.settle(on: find.byType(MoreScreen));
    await d.hold(1.5);

    await d.tap(
      find.byWidgetPredicate(
        (w) => w is IqPressable && w.semanticLabel == 'Your profile',
      ),
      label: 'your-profile',
    );
    await d.arrive(find.byType(ProfileScreen), hold: 1.8);
    await d.tap(find.text('Your details'), label: 'your-details');
    await d.arrive(find.byType(YourDetailsScreen), hold: 1.8);

    await d.tap(find.text('Phone number'));
    await d.arrive(find.byType(EditDetailScreen), hold: 0.8);
    await d.tap(find.byType(EditableText), label: 'phone');
    await d.hold(0.4);
    await d.erase(4);
    await d.hold(0.3);
    await d.type('4410');
    await d.hold(1);
    await d.tap(button('Save'), label: 'save');
    await d.arrive(find.byType(PhoneCodeScreen), hold: 1);
    await d.type('482152');
    await d.hold(1);
    await d.tap(button('Confirm'), label: 'confirm');
    await d.gone(find.byType(PhoneCodeScreen));
    await d.arrive(find.byType(YourDetailsScreen), hold: 1.5);

    await d.tap(find.text('Occupation'));
    await d.arrive(find.byType(EditDetailScreen), hold: 0.8);
    await d.tap(find.text('Employed'));
    await d.hold(0.8);
    await d.tap(button('Save'), label: 'save');
    await d.arrive(find.byType(YourDetailsScreen), hold: 1.5);

    final interests = find.text('Interests');
    await d.reveal(interests, listIn(find.byType(YourDetailsScreen)));
    await d.hold(0.4);
    await d.tap(interests);
    await d.arrive(find.byType(EditDetailScreen), hold: 0.8);
    await d.tap(find.text('Health'));
    await d.hold(0.8);
    await d.tap(button('Save'), label: 'save');
    await d.arrive(find.byType(YourDetailsScreen), hold: 1.8);
    await d.back();
    await d.arrive(find.byType(ProfileScreen), hold: 1);
    await d.back();

    await d.arrive(find.byType(MoreScreen), hold: 2);
  });
}
