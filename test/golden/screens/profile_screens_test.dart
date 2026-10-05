import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'profile_harness.dart';

Future<void> _golden(String name) =>
    expectMatchesGolden(find.byType(MaterialApp), 'goldens/$name.png');

void main() {
  setUpAll(loadAppFonts);
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  testWidgets('40:24 Profile', (tester) async {
    await pumpProfileApp(tester, Routes.profile);
    await _golden('profile_profile');
  });

  testWidgets('40:141 Your details', (tester) async {
    await pumpProfileApp(tester, Routes.yourDetails);
    await _golden('profile_your_details');
  });

  testWidgets('Your details, an edit not yet saved', (tester) async {
    await pumpProfileApp(tester, Routes.yourDetails);
    await tester.enterText(find.byType(TextField), '+234 801 234 567');
    await tester.pump();
    await _golden('profile_your_details_editing');
    await tester.pump(ProfileService.typingPause);
    await tester.pumpAndSettle();
  });

  testWidgets('Your details, a save the account refused', (tester) async {
    final service = TestProfileService()..fail = true;
    await pumpProfileApp(tester, Routes.yourDetails, service: service);
    await tester.tap(find.text('Gender'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    await _golden('profile_your_details_failed');
  });

  testWidgets('Your details, Save changes landed', (tester) async {
    await pumpProfileApp(tester, Routes.yourDetails);
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await _golden('profile_your_details_saved');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  });

  testWidgets('Your details, interests sheet', (tester) async {
    await pumpProfileApp(tester, Routes.yourDetails);
    await tester.tap(find.text('Marketing & advertising · Finance & fintech'));
    await tester.pumpAndSettle();
    await _golden('profile_interests_sheet');
  });

  testWidgets('Your details, date of birth sheet', (tester) async {
    await pumpProfileApp(tester, Routes.yourDetails);
    await tester.tap(find.text('14 March 1998'));
    await tester.pumpAndSettle();
    await _golden('profile_date_of_birth_sheet');
  });

  testWidgets('194:9932 Notification preferences', (tester) async {
    await pumpProfileApp(tester, Routes.notificationPreferences);
    await _golden('settings_notification_preferences');
  });

  testWidgets('194:9964 Delete account', (tester) async {
    await pumpProfileApp(tester, Routes.deleteAccount);
    await _golden('settings_delete_account');
  });

  testWidgets('194:10046 Delete account, typed', (tester) async {
    await pumpProfileApp(tester, Routes.deleteAccount);
    await tester.enterText(find.byType(TextField), 'DELETE');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _golden('settings_delete_account_typed');
  });

  testWidgets('225:10830 Account closing', (tester) async {
    await pumpProfileApp(tester, Routes.accountClosing);
    await _golden('settings_account_closing');
  });
}
