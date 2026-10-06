import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/notifications_ask_screen.dart';
import 'package:iqly_mobile/features/entry/password_screen.dart';
import 'package:iqly_mobile/features/entry/your_name_screen.dart';
import 'package:iqly_mobile/features/onboarding/about_you_screen.dart';
import 'package:iqly_mobile/features/onboarding/done_screen.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_sheets.dart';
import 'package:iqly_mobile/features/onboarding/welcome_screen.dart';
import 'package:iqly_mobile/features/onboarding/what_you_like_screen.dart';
import 'package:iqly_mobile/features/onboarding/where_you_live_screen.dart';
import 'package:iqly_mobile/features/onboarding/where_you_studied_screen.dart';
import 'package:iqly_mobile/features/profile/profile_sheets.dart';
import 'package:iqly_mobile/ui/box_field.dart';
import 'package:iqly_mobile/ui/field.dart';

import '../harness.dart';
import '../steps.dart';

/// Fresh install to Discover: splash, landing, sign up with a new email,
/// name and password, then onboarding (what you do and date of birth, State
/// and City sheets with a phone number, Where you studied, interests), Done,
/// the notifications ask and the first tip.
void main() {
  film('first_open_signup', (d) async {
    await d.arrive(find.byType(LandingScreen), hold: 2);
    await d.tap(find.byType(IqBoxField), label: 'email-box');
    await d.hold(0.5);
    await d.type('tolu.bello@example.com');
    await d.hold(0.8);
    await d.tap(button('Continue'), label: 'continue');

    await d.arrive(find.byType(YourNameScreen));
    await d.type('Tolu');
    await d.hold(0.3);
    await d.submit();
    await d.hold(0.3);
    await d.type('Bello');
    await d.hold(0.8);
    await d.tap(button('Continue'), label: 'continue');

    await d.arrive(find.byType(PasswordScreen));
    await d.type('Lagos2026!');
    await d.hold(0.8);
    await d.tap(find.text('Show'));
    await d.hold(1.2);
    await d.tap(find.text('Hide'));
    await d.hold(0.8);
    await d.tap(button('Create account'), label: 'create-account');

    await d.arrive(find.byType(WelcomeScreen), hold: 2);
    await d.tap(button('Start'), label: 'start');

    await d.arrive(find.byType(AboutYouScreen));
    await d.tap(find.text('Student'));
    await d.hold(0.8);
    await d.tap(find.text('Select…'), label: 'date-of-birth');
    await d.arrive(find.byType(DateOfBirthSheet), hold: 0.8);
    await d.scroll(find.bySemanticsLabel('Month'), 96, seconds: 0.6);
    await d.hold(0.6);
    await d.scroll(find.bySemanticsLabel('Year'), 144, seconds: 0.7);
    await d.hold(1);
    await d.tap(button('Use this'), label: 'use-this');
    await d.gone(find.byType(DateOfBirthSheet));
    await d.hold(1);
    await d.tap(button('Continue'), label: 'continue');

    await d.arrive(find.byType(WhereYouLiveScreen));
    await d.tap(find.text('Select state'));
    await d.arrive(find.byType(OptionSheet));
    await d.pickFromSheet('Lagos');
    await d.hold(0.6);
    await d.tap(button('Use this'), label: 'use-this');
    await d.gone(find.byType(OptionSheet));
    await d.hold(0.8);
    await d.tap(find.text('Select city'));
    await d.arrive(find.byType(CitySheet));
    await d.tap(find.text('Ikeja'));
    await d.hold(0.8);
    await d.tap(button('Use this'), label: 'use-this');
    await d.gone(find.byType(CitySheet));
    await d.hold(0.8);
    await d.tap(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is IqField && w.label == 'Phone number (optional)',
        ),
        matching: find.byType(EditableText),
      ),
      label: 'phone',
    );
    await d.type('8035550142');
    await d.hold(1);
    await d.tap(find.text('Where do you live?'), label: 'put-keypad-away');
    await d.hold(0.8);
    await d.tap(button('Continue'), label: 'continue');

    await d.arrive(find.byType(WhereYouStudiedScreen));
    await d.tap(find.text('Select…'), label: 'education');
    await d.arrive(find.byType(OptionSheet));
    await d.pickFromSheet('HND / BSc');
    await d.hold(0.6);
    await d.tap(button('Use this'), label: 'use-this');
    await d.gone(find.byType(OptionSheet));
    await d.hold(0.8);
    await d.tap(find.text('Search universities'));
    await d.arrive(find.byType(UniversitySheet));
    await d.type('Lag', cps: 8);
    await d.hold(1.2);
    await d.tap(find.text('University of Lagos'));
    await d.hold(0.8);
    await d.tap(button('Use this'), label: 'use-this');

    await d.arrive(find.byType(WhatYouLikeScreen));
    await d.tap(find.text('Marketing & advertising'));
    await d.hold(0.6);
    await d.tap(find.text('Finance & fintech'));
    await d.hold(0.6);
    await d.tap(find.text('Product design'));
    await d.hold(0.8);
    await d.tap(button('Finish'), label: 'finish');

    await d.arrive(find.byType(DoneScreen), hold: 2.5);
    await d.tap(button('Go to Discover'), label: 'go-to-discover');

    await d.arrive(find.byType(NotificationsAskScreen));
    await d.tap(button('Turn on notifications'), label: 'turn-on');

    await d.waitFor(find.byType(HomeScreen));
    await readFirstTip(d);
  });
}
