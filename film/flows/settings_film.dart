import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/more/more_screen.dart';
import 'package:iqly_mobile/features/profile/profile_screen.dart';
import 'package:iqly_mobile/features/settings/delete_account_screen.dart';
import 'package:iqly_mobile/features/settings/notification_preferences_screen.dart';
import 'package:iqly_mobile/ui/confirm_sheet.dart';
import 'package:iqly_mobile/ui/pressable.dart';
import 'package:iqly_mobile/ui/switch.dart';

import '../harness.dart';
import '../steps.dart';

Finder _switchFor(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
  matching: find.byType(IqSwitch),
);

/// A returning contributor tunes the app from More: Your profile's
/// Notification preferences (two switches), then Delete account, still
/// locked while the wallet holds money, Keep my account, and Sign out
/// answered with Stay signed in.
void main() {
  film('settings', prefs: returning, (d) async {
    await onDiscover(d, hold: 1);
    await dockTab(d, 'More');
    await d.waitFor(find.text('Help centre'));
    await d.settle(on: find.byType(MoreScreen));
    await d.hold(1.2);

    await d.tap(
      find.byWidgetPredicate(
        (w) => w is IqPressable && w.semanticLabel == 'Your profile',
      ),
      label: 'your-profile',
    );
    await d.arrive(find.byType(ProfileScreen), hold: 1.2);
    await d.tap(find.text('Notification preferences'), label: 'preferences');
    await d.arrive(find.byType(NotificationPreferencesScreen), hold: 1.5);
    await d.tap(_switchFor('New briefs for you'), label: 'new-briefs');
    await d.hold(1.2);
    await d.tap(_switchFor('Polls'), label: 'polls');
    await d.hold(1.5);
    await d.back();
    await d.arrive(find.byType(ProfileScreen), hold: 0.8);
    await d.back();
    await d.arrive(find.byType(MoreScreen), hold: 0.8);

    final delete = find.text('Delete account');
    await revealAndTap(d, delete, find.byType(MoreScreen));
    await d.arrive(find.byType(DeleteAccountScreen), hold: 2);
    final typed = find.byType(EditableText);
    await d.reveal(typed, listIn(find.byType(DeleteAccountScreen)));
    await d.tap(typed, label: 'type-delete');
    await d.type('delete');
    await d.hold(2);
    await d.tap(button('Keep my account'), label: 'keep-my-account');
    await d.arrive(find.byType(MoreScreen), hold: 1);

    final signOut = find.text('Sign out');
    await revealAndTap(d, signOut, find.byType(MoreScreen));
    await d.arrive(find.byType(IqConfirmSheet), hold: 1.8);
    await d.tap(find.text('Stay signed in'), label: 'stay-signed-in');
    await d.gone(find.byType(IqConfirmSheet));
    await d.settle(on: find.byType(MoreScreen));
    await d.hold(1.5);
  });
}
