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
import 'package:iqly_mobile/ui/box_field.dart';
import 'package:iqly_mobile/ui/next_fab.dart';

import '../harness.dart';
import '../steps.dart';

/// Fresh install to Discover: splash, landing, sign up with a new email,
/// the three onboarding steps, Done, the notifications ask and the first tip.
void main() {
  film('first_open_signup', (d) async {
    await d.arrive(find.byType(LandingScreen), hold: 2);
    await d.tap(find.byType(IqBoxField), label: 'email-box');
    await d.hold(0.5);
    await d.type('adaeze.o@example.com');
    await d.hold(0.8);
    await d.tap(find.text('Continue'));

    await d.arrive(find.byType(YourNameScreen));
    await d.type('Adaeze');
    await d.hold(0.3);
    await d.submit();
    await d.hold(0.3);
    await d.type('Okafor');
    await d.hold(0.8);
    await d.tap(find.byType(IqNextFab), label: 'next');

    await d.arrive(find.byType(PasswordScreen));
    await d.type('Lagos2026!');
    await d.hold(0.8);
    await d.tap(find.text('Show'));
    await d.hold(1.2);
    await d.tap(find.text('Hide'));
    await d.hold(0.8);
    await d.tap(find.byType(IqNextFab), label: 'next');

    await d.arrive(find.byType(WelcomeScreen), hold: 2);
    await d.tap(find.text('Start'));

    await d.arrive(find.byType(AboutYouScreen));
    await d.tap(find.text('Student'));
    await d.hold(0.8);
    await d.tap(find.byType(IqNextFab), label: 'next');

    await d.arrive(find.byType(WhereYouLiveScreen));
    await d.tap(find.text('Select state'));
    await d.arrive(find.byType(OptionSheet));
    await d.pickFromSheet('Lagos');
    await d.gone(find.byType(OptionSheet));
    await d.hold(0.8);
    await d.tap(find.text('Select city'));
    await d.arrive(find.byType(CitySheet));
    await d.tap(find.text('Ikeja'));
    await d.hold(0.8);
    await d.tap(find.text('Use this'));
    await d.gone(find.byType(CitySheet));
    await d.hold(0.8);
    await d.tap(find.byType(IqNextFab), label: 'next');

    await d.arrive(find.byType(WhereYouStudiedScreen));
    await d.tap(find.text('Select…'));
    await d.arrive(find.byType(OptionSheet));
    await d.pickFromSheet('HND / BSc');
    await d.gone(find.byType(OptionSheet));
    await d.hold(0.8);
    await d.tap(find.text('Search universities'));
    await d.arrive(find.byType(UniversitySheet));
    await d.type('Lag', cps: 8);
    await d.hold(1.2);
    await d.tap(find.text('University of Lagos'));
    await d.hold(0.8);
    await d.tap(find.text('Use this'));

    await d.arrive(find.byType(WhatYouLikeScreen));
    await d.tap(find.text('Marketing & advertising'));
    await d.hold(0.6);
    await d.tap(find.text('Finance & fintech'));
    await d.hold(0.8);
    await d.tap(find.byType(IqNextFab), label: 'finish');

    await d.arrive(find.byType(DoneScreen), hold: 2.5);
    await d.tap(find.text('Continue'));

    await d.arrive(find.byType(NotificationsAskScreen));
    await d.tap(find.text('Turn on notifications'));

    await d.waitFor(find.byType(HomeScreen));
    await readFirstTip(d);
  });
}
