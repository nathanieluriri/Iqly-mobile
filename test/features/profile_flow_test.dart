import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/discover/saved_briefs_screen.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_draft.dart';
import 'package:iqly_mobile/features/profile/profile_screen.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/features/profile/your_details_screen.dart';
import 'package:iqly_mobile/features/settings/account_closing_screen.dart';
import 'package:iqly_mobile/features/settings/delete_account_screen.dart';
import 'package:iqly_mobile/features/settings/notification_preferences_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/pressable.dart';
import 'package:iqly_mobile/ui/setting_row.dart';
import 'package:iqly_mobile/ui/switch.dart';
import 'package:iqly_mobile/ui/top_bar.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/profile_harness.dart';

/// Taps, then lets timers that close a screen (the Save changes check)
/// run out before settling.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

IqButton _button(WidgetTester tester, String label) =>
    tester.widget<IqButton>(find.widgetWithText(IqButton, label));

IqSwitchState _switch(WidgetTester tester, String label) => tester
    .widget<IqSwitch>(
      find.descendant(
        of: find.ancestor(
          of: find.text(label),
          matching: find.byType(IqSettingRow),
        ),
        matching: find.byType(IqSwitch),
      ),
    )
    .state;

Finder get _bell => find
    .descendant(of: find.byType(IqTopBar), matching: find.byType(IqPressable))
    .first;

void main() {
  testWidgets('Profile to Your details: every field edits the one profile '
      'and Save changes returns', (tester) async {
    final semantics = tester.ensureSemantics();
    final service = TestProfileService();
    final container = await pumpProfileApp(
      tester,
      Routes.profile,
      service: service,
    );
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Adaeze Okafor'), findsOneWidget);
    expect(find.text('adaeze@example.com'), findsOneWidget);
    expect(find.text('Access Bank ••6789'), findsOneWidget);

    await _tap(tester, find.text('Your details'));
    expect(find.byType(YourDetailsScreen), findsOneWidget);
    expect(find.text(YourDetailsScreen.readyText), findsOneWidget);
    expect(find.text('+234 801 234 5678'), findsOneWidget);
    expect(find.text('14 March 1998'), findsOneWidget);
    expect(find.text('Ikeja'), findsOneWidget);
    expect(find.text('University of Lagos'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '+234 809 000 1111');
    await tester.pump();
    expect(find.text(YourDetailsScreen.readyText), findsNothing);
    await tester.pump(ProfileService.typingPause);
    await tester.pumpAndSettle();
    expect(find.text(YourDetailsScreen.readyText), findsOneWidget);
    expect(service.details.phone, '+234 809 000 1111');

    await _tap(tester, find.text('STATE OF ORIGIN'));
    expect(find.text('State of origin'), findsWidgets);
    await _tap(tester, find.text('Anambra'));
    expect(find.text('Anambra'), findsOneWidget);
    expect(service.details.stateOfOrigin, 'Anambra');

    await _tap(tester, find.text('GENDER'));
    await _tap(tester, find.text('Female'));
    expect(find.text('Female'), findsOneWidget);
    expect(service.details.gender, 'female');

    await _tap(tester, find.text('INTERESTS'));
    await _tap(tester, find.text('Technology'));
    await _tap(tester, find.text('Use this'));
    expect(
      find.text('Marketing & advertising · Finance & fintech · Technology'),
      findsOneWidget,
    );
    final interests = [
      'marketing_advertising',
      'finance_fintech',
      'tech_gadgets',
    ];
    expect(
      container.read(onboardingDraftProvider).profile.interests,
      interests,
    );
    expect(container.read(feedInterestsProvider), interests);
    expect(service.answers?.interests, interests);

    await _tap(tester, find.text('STATE OF RESIDENCE'));
    await tester.scrollUntilVisible(
      find.text('Ogun'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await _tap(tester, find.text('Ogun'));
    expect(find.text('Ogun'), findsOneWidget);
    expect(find.text('Ikeja'), findsNothing);
    expect(container.read(onboardingDraftProvider).profile.state, 'Ogun');
    expect(container.read(onboardingDraftProvider).profile.city, '');

    await _tap(tester, find.text('CITY'));
    await _tap(tester, find.text('Abeokuta'));
    await _tap(tester, find.text('Use this'));
    expect(find.text('Abeokuta'), findsOneWidget);
    expect(container.read(onboardingDraftProvider).profile.city, 'Abeokuta');

    await _tap(tester, find.text('DATE OF BIRTH'));
    expect(find.text('Date of birth'), findsWidgets);
    await _tap(tester, find.text('Use this'));
    expect(find.text('14 March 1998'), findsOneWidget);

    final saves = service.saves;
    await _tap(tester, find.text('Save changes'));
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(YourDetailsScreen), findsNothing);
    expect(service.saves, saves);
    expect(service.answers?.city, 'Abeokuta');

    await _tap(tester, find.text('Your details'));
    expect(find.text('Anambra'), findsOneWidget);
    expect(find.text('Abeokuta'), findsOneWidget);
    expect(find.text('+234 809 000 1111'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(ProfileScreen), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a save the account refuses shows the error; Save changes '
      'retries and returns', (tester) async {
    final service = TestProfileService()..fail = true;
    await pumpProfileApp(tester, Routes.yourDetails, service: service);

    await _tap(tester, find.text('GENDER'));
    await _tap(tester, find.text('Male'));
    expect(find.text(YourDetailsScreen.errorText), findsOneWidget);

    await _tap(tester, find.text('Save changes'));
    expect(find.byType(YourDetailsScreen), findsOneWidget);
    expect(find.text(YourDetailsScreen.errorText), findsOneWidget);

    service.fail = false;
    await _tap(tester, find.text('Save changes'));
    expect(find.byType(YourDetailsScreen), findsNothing);
    expect(service.details.gender, 'male');
  });

  testWidgets('Save changes waits for a save still on its way', (tester) async {
    final service = TestProfileService()..hold = true;
    await pumpProfileApp(tester, Routes.yourDetails, service: service);
    await _tap(tester, find.text('GENDER'));
    await _tap(tester, find.text('Prefer not to say'));

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.byType(YourDetailsScreen), findsOneWidget);
    expect(tester.widget<IqButton>(find.byType(IqButton)).loading, isTrue);

    service.release();
    await tester.pumpAndSettle();
    expect(find.byType(YourDetailsScreen), findsNothing);
    expect(service.details.gender, 'prefer_not_to_say');
  });

  testWidgets('Notification preferences: a flip saves, a refused flip goes '
      'back', (tester) async {
    final semantics = tester.ensureSemantics();
    final service = TestProfileService();
    await pumpProfileApp(tester, Routes.profile, service: service);
    await _tap(tester, find.text('Notifications'));
    expect(find.byType(NotificationPreferencesScreen), findsOneWidget);
    expect(_switch(tester, 'Polls'), IqSwitchState.off);
    expect(_switch(tester, 'Results'), IqSwitchState.on);

    await _tap(tester, find.text('Polls'));
    expect(_switch(tester, 'Polls'), IqSwitchState.on);
    expect(service.preferences[NotificationTopic.polls], isTrue);

    service.fail = true;
    await _tap(tester, find.text('Results'));
    expect(_switch(tester, 'Results'), IqSwitchState.on);
    expect(service.preferences[NotificationTopic.results], isTrue);

    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(ProfileScreen), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Delete account: withdraw first, typed DELETE, closing, Done '
      'to the landing', (tester) async {
    final service = TestProfileService();
    final container = await pumpProfileApp(
      tester,
      Routes.profile,
      service: service,
    );
    await _tap(tester, find.text('Delete account'));
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(find.text('Withdraw ₦12,500.00 first'), findsOneWidget);
    expect(find.text('₦10,000.00 on its way'), findsOneWidget);
    expect(_button(tester, 'Delete my account').disabled, isTrue);

    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    expect(service.deletions, 0);

    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pumpAndSettle();
    expect(find.text('DELETE'), findsOneWidget);
    expect(_button(tester, 'Delete my account').disabled, isFalse);

    await _tap(tester, find.text('Delete my account'));
    expect(find.byType(AccountClosingScreen), findsOneWidget);
    expect(find.text('Your account is closing'), findsOneWidget);
    expect(service.deletions, 1);
    expect(container.read(sessionProvider).signedIn, isFalse);

    await _tap(tester, find.text('Done'));
    expect(find.byType(LandingScreen), findsOneWidget);
  });

  testWidgets('Keep my account and back return to Profile; Withdraw first '
      'opens the Wallet', (tester) async {
    await pumpProfileApp(tester, Routes.profile);
    await _tap(tester, find.text('Delete account'));
    await _tap(tester, find.text('Keep my account'));
    expect(find.byType(ProfileScreen), findsOneWidget);

    await _tap(tester, find.text('Delete account'));
    await _tap(tester, find.text('Withdraw ₦12,500.00 first'));
    expect(find.byType(DeleteAccountScreen), findsNothing);
    expect(find.text('Wallet'), findsWidgets);
  });

  testWidgets('Changed your mind? Sign in opens Sign in with the email', (
    tester,
  ) async {
    await pumpProfileApp(tester, Routes.deleteAccount);
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Delete my account'));
    await _tap(tester, find.text('Changed your mind? Sign in'));
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('adaeze@example.com'), findsOneWidget);
  });

  testWidgets('Sign out forgets the account and lands on the landing', (
    tester,
  ) async {
    final service = TestProfileService();
    final container = await pumpProfileApp(
      tester,
      Routes.profile,
      service: service,
      prefs: {
        ...signedInPrefs(),
        'onboarding.draft': '{"state":"Lagos","city":"Ikeja"}',
        'profile.details': '{"phone":"+234 801 234 5678"}',
      },
    );
    await _tap(tester, find.text('Sign out'));
    expect(find.byType(LandingScreen), findsOneWidget);
    expect(service.signOuts, 1);
    final session = container.read(sessionProvider);
    expect(session.signedIn, isFalse);
    expect(session.onboardingDone, isFalse);
    expect(session.firstTipSeen, isFalse);
    final prefs = container.read(sharedPreferencesProvider);
    expect(prefs.getString('onboarding.draft'), isNull);
    expect(prefs.getString('profile.details'), isNull);
    expect(container.read(onboardingDraftProvider).profile.state, isNull);
    expect(container.read(detailsSaveProvider).settled, isTrue);
  });

  testWidgets('Saved briefs opens the Saved lens on Discover', (tester) async {
    await pumpProfileApp(tester, Routes.profile);
    await _tap(tester, find.text('Saved briefs'));
    expect(find.byType(SavedBriefsScreen), findsOneWidget);
  });

  testWidgets('Bank account opens Withdraw; the bell opens Notifications', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpProfileApp(tester, Routes.profile);
    await _tap(tester, find.text('Bank account'));
    expect(find.text('Withdraw'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(ProfileScreen), findsOneWidget);

    await _tap(tester, _bell);
    expect(find.byType(ProfileScreen), findsNothing);
    expect(find.text('Notifications'), findsOneWidget);
    semantics.dispose();
  });
}
