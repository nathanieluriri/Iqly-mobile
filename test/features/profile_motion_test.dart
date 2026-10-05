import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/profile/profile_screen.dart';
import 'package:iqly_mobile/features/profile/profile_sheets.dart';
import 'package:iqly_mobile/features/profile/your_details_screen.dart';
import 'package:iqly_mobile/features/settings/account_closing_screen.dart';
import 'package:iqly_mobile/features/settings/delete_account_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/dock.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/illustration.dart';
import 'package:iqly_mobile/ui/setting_row.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/profile_harness.dart';
import 'entry_harness.dart';
import 'phone_keyboard.dart';

const _ms = Duration(milliseconds: 1);
const _success = 'HapticFeedbackType.successNotification';
const _destructive = 'HapticFeedbackType.mediumImpact';
const _error = 'HapticFeedbackType.mediumImpact';

double _eo(double t) => IqCurves.easeOut.transform(t);

/// The product of the fades between [of] and the screen.
double _opacity(WidgetTester tester, Finder of) {
  var opacity = 1.0;
  for (final widget in tester.widgetList(
    find.ancestor(
      of: of,
      matching: find.byWidgetPredicate(
        (w) => w is FadeTransition || w is Opacity,
      ),
    ),
  )) {
    opacity *= widget is FadeTransition
        ? widget.opacity.value
        : (widget as Opacity).opacity;
  }
  return opacity;
}

/// How far the stagger slot [of] sits in is still raised.
double _raised(WidgetTester tester, Finder of) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.ancestor(of: of, matching: find.byType(StaggerItem)).first,
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .getTranslation()
    .y;

double _arrive(WidgetTester tester, Finder of) => tester
    .widget<FadeTransition>(
      find
          .descendant(
            of: find.ancestor(of: of, matching: find.byType(StaggerItem)).first,
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  group('Profile', () {
    testWidgets('rows arrive 40 ms apart on the first visit only', (
      tester,
    ) async {
      await pumpProfileApp(
        tester,
        Routes.profile,
        reducedMotion: false,
        settle: false,
      );
      await tester.pump();
      final details = find.text('Your details');
      final signOut = find.text('Sign out');
      expect(_arrive(tester, details), closeTo(0, 0.01));
      await tester.pump(_ms * 130);
      expect(_arrive(tester, details), closeTo(_eo(90 / 260), 0.01));
      expect(_raised(tester, details), closeTo(12 * (1 - _eo(90 / 260)), 0.1));
      expect(_arrive(tester, signOut), lessThan(_arrive(tester, details)));
      await tester.pump(_ms * 331);
      expect(_arrive(tester, signOut), 1);
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(IqDock),
          matching: find.text('Submissions'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(IqDock), matching: find.text('More')),
      );
      await tester.pump();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(_arrive(tester, details), 1);
    });

    testWidgets('Sign out hands off to the landing, 300', (tester) async {
      await pumpProfileApp(tester, Routes.profile, reducedMotion: false);
      await tester.tap(find.text('Sign out'));
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 150);
      final landing = find.byType(LandingScreen);
      expect(_opacity(tester, landing), closeTo(_eo(0.5), 0.02));
      expect(tester.getTopLeft(landing).dx, 0);
      await tester.pump(_ms * 151);
      expect(_opacity(tester, landing), 1);
    });

    testWidgets('a switch flip gives the select haptic; the list does not '
        'stagger', (tester) async {
      final haptics = recordHaptics(tester);
      await pumpProfileApp(tester, Routes.notificationPreferences);
      expect(
        find.ancestor(
          of: find.byType(IqSettingRow).first,
          matching: find.byType(StaggerItem),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Polls'));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });
  });

  group('Your details', () {
    testWidgets('pushes in from 24 over 300 as its fields settle 40 apart', (
      tester,
    ) async {
      await pumpProfileApp(tester, Routes.profile, reducedMotion: false);
      await tester.tap(find.text('Your details'));
      await tester.pump();
      await tester.pump();
      final page = find.byType(YourDetailsScreen);
      final phone = find.text('Phone number');
      expect(_raised(tester, phone), closeTo(8, 0.01));
      expect(_arrive(tester, phone), 1);
      await tester.pump(_ms * 150);
      expect(tester.getTopLeft(page).dx, closeTo(24 * (1 - _eo(0.5)), 0.5));
      expect(_raised(tester, phone), closeTo(8 * (1 - _eo(150 / 260)), 0.05));
      await tester.pump(_ms * 151);
      expect(tester.getTopLeft(page).dx, 0);
      await tester.pumpAndSettle();
      expect(_raised(tester, phone), 0);
    });

    testWidgets('a back tap halfway through the push pops it', (tester) async {
      await pumpProfileApp(tester, Routes.profile, reducedMotion: false);
      await tester.tap(find.text('Your details'));
      await tester.pump();
      await tester.pump(_ms * 150);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pump();
      await tester.pump(_ms * 241);
      await tester.pump();
      expect(find.byType(YourDetailsScreen), findsNothing);
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('the thread reads Ready on arrival, turns Progress with its '
        'words and count on an edit, and Ready again when it saves', (
      tester,
    ) async {
      final service = TestProfileService()..hold = true;
      await pumpProfileApp(
        tester,
        Routes.yourDetails,
        service: service,
        reducedMotion: false,
        settle: false,
      );
      await tester.pumpAndSettle();
      expect(find.text(YourDetailsScreen.readyText), findsOneWidget);

      await tester.enterText(find.byType(TextField), '+234 809 000 1111');
      await tester.pumpAndSettle();
      expect(find.text(YourDetailsScreen.savingText), findsOneWidget);
      expect(find.text('7 of 8'), findsOneWidget);

      await tester.pump(ProfileService.typingPause);
      service.release();
      await tester.pumpAndSettle();
      expect(find.text(YourDetailsScreen.readyText), findsOneWidget);
    });

    testWidgets('a refused save reads the new words and shakes on Save '
        'changes, with the error haptic', (tester) async {
      final haptics = recordHaptics(tester);
      final service = TestProfileService()..fail = true;
      await pumpProfileApp(tester, Routes.yourDetails, service: service);
      await tester.enterText(find.byType(TextField), '+234 809 000 1111');
      await tester.pump(ProfileService.typingPause);
      await tester.pumpAndSettle();
      expect(find.text(YourDetailsScreen.errorText), findsOneWidget);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(haptics, [_error]);
      expect(find.byType(YourDetailsScreen), findsOneWidget);
    });

    testWidgets('Save changes commits, lands its check on the stamp curve '
        'with the success haptic, then returns', (tester) async {
      final haptics = recordHaptics(tester);
      await pumpProfileApp(tester, Routes.profile, reducedMotion: false);
      await tester.tap(find.text('Your details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      await tester.pump();
      expect(haptics, [_success]);
      double check() => tester
          .widget<ScaleTransition>(
            find.ancestor(
              of: find.byWidgetPredicate(
                (w) => w is IqIcon && w.icon == IqIcons.check,
              ),
              matching: find.byType(ScaleTransition),
            ),
          )
          .scale
          .value;
      expect(check(), closeTo(0.6, 0.01));
      var peak = 0.0;
      for (var i = 0; i < 20; i++) {
        await tester.pump(_ms * 10);
        if (find.byType(YourDetailsScreen).evaluate().isEmpty) break;
        peak = check() > peak ? check() : peak;
      }
      expect(peak, greaterThan(1));
      expect(peak, lessThan(1.06));
      await tester.pumpAndSettle();
      expect(find.byType(YourDetailsScreen), findsNothing);
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('Save changes with the keypad up: the page keeps its layout '
        'as it leaves, the keypad going with it', (tester) async {
      await pumpProfileApp(tester, Routes.profile, reducedMotion: false);
      final keyboard = PhoneKeyboard(tester);
      await tester.tap(find.text('Your details'));
      await keyboard.frames(30);
      await tester.tap(find.byType(TextField));
      await keyboard.until(() => keyboard.inset == PhoneKeyboard.height);

      final button = find.descendant(
        of: find.byType(YourDetailsScreen),
        matching: find.byType(IqButton),
      );
      final top = tester.getTopLeft(button).dy;
      expect(top, lessThan(844 - PhoneKeyboard.height));
      await tester.tap(find.text('Save changes'));
      for (var i = 0; i < 60 && button.evaluate().isNotEmpty; i++) {
        await keyboard.frame();
        if (button.evaluate().isNotEmpty) {
          expect(tester.getTopLeft(button).dy, top);
        }
      }
      expect(find.byType(YourDetailsScreen), findsNothing);
      expect(keyboard.inset, lessThan(PhoneKeyboard.height));
      await keyboard.frames(20);
      expect(keyboard.inset, 0);
    });

    testWidgets('reduced motion: the check lands at once', (tester) async {
      await pumpProfileApp(tester, Routes.yourDetails);
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      await tester.pump(_ms * 50);
      expect(
        tester
            .widget<ScaleTransition>(
              find.ancestor(
                of: find.byWidgetPredicate(
                  (w) => w is IqIcon && w.icon == IqIcons.check,
                ),
                matching: find.byType(ScaleTransition),
              ),
            )
            .scale
            .value,
        1,
      );
      await tester.pumpAndSettle();
    });
  });

  group('sheets', () {
    double useThis(WidgetTester tester) =>
        tester.getTopLeft(find.text('Use this')).dy;

    testWidgets('Interests and Date of birth keep the University sheet\'s '
        'foot', (tester) async {
      await pumpProfileApp(tester, Routes.yourDetails);
      await tester.tap(find.text('University'));
      await tester.pumpAndSettle();
      final university = useThis(tester);
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();

      for (final field in ['Interests', 'Date of birth']) {
        await tester.tap(find.text(field));
        await tester.pumpAndSettle();
        expect(useThis(tester), university, reason: field);
        await tester.tap(find.bySemanticsLabel('Close'));
        await tester.pumpAndSettle();
      }
    });

    Widget wheel(DateTime initial) => MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: DateOfBirthSheet(initial: initial, today: figmaNow),
        ),
      ),
    );

    TextStyle style(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text)).style!;

    testWidgets('the date wheel: the row on the band in Mob/Title on fg, the '
        'rest in Mob/Body on fg2, days the month lacks on fg3', (tester) async {
      await tester.pumpWidget(wheel(DateTime(1998, 2, 14)));
      expect(style(tester, '14').fontSize, IqText.title.fontSize);
      expect(style(tester, '14').color, IqColors.fg);
      expect(style(tester, 'March').fontFamily, IqText.body.fontFamily);
      expect(style(tester, 'March').fontSize, IqText.body.fontSize);
      expect(style(tester, 'March').color, IqColors.fg2);
      expect(style(tester, '1997').color, IqColors.fg2);
      await tester.drag(find.text('14'), const Offset(0, -44.0 * 15));
      await tester.pumpAndSettle();
      expect(style(tester, '30').color, IqColors.fg3);
    });

    testWidgets('a day the month lacks turns back to its last day', (
      tester,
    ) async {
      await tester.pumpWidget(wheel(DateTime(1998, 3, 31)));
      await tester.tap(find.text('February'));
      await tester.pumpAndSettle();
      expect(style(tester, '28').fontSize, IqText.title.fontSize);
      expect(style(tester, 'February').color, IqColors.fg);
    });

    testWidgets('a date after today turns back to today', (tester) async {
      await tester.pumpWidget(wheel(DateTime(2026, 10, 3)));
      expect(style(tester, 'November').color, IqColors.fg3);
      await tester.tap(find.text('November'));
      await tester.pumpAndSettle();
      expect(style(tester, 'October').color, IqColors.fg);
    });
  });

  group('Delete account', () {
    testWidgets('the press gives the destructive haptic and hands off to '
        'Account closing, 300, no success haptic', (tester) async {
      final haptics = recordHaptics(tester);
      await pumpProfileApp(tester, Routes.deleteAccount, reducedMotion: false);
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete my account'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      final closing = find.byType(AccountClosingScreen);
      await tester.pump(_ms * 150);
      expect(_opacity(tester, closing), lessThan(1));
      expect(tester.getTopLeft(closing).dx, 0);
      await tester.pumpAndSettle();
      expect(haptics, [_destructive]);
    });

    testWidgets('a failed delete shakes, buzzes and says why under the '
        'button; a new try clears it', (tester) async {
      final haptics = recordHaptics(tester);
      final service = TestProfileService()..fail = true;
      await pumpProfileApp(
        tester,
        Routes.deleteAccount,
        service: service,
        reducedMotion: false,
      );
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete my account'));
      await tester.pump();
      await tester.pump();
      final line = find.text(DeleteAccountScreen.failedText);
      expect(line, findsOneWidget);
      expect(_opacity(tester, line), 0);
      await tester.pump(_ms * 80);
      expect(_opacity(tester, line), closeTo(_eo(0.5), 0.01));
      await tester.pumpAndSettle();
      expect(_opacity(tester, line), 1);
      expect(haptics, [_destructive, _error]);

      service.fail = false;
      await tester.tap(find.text('Delete my account'));
      await tester.pump();
      expect(line, findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(AccountClosingScreen), findsOneWidget);
    });
  });

  testWidgets('Account closing: the Megaphone rises 16 over 320, the title '
      'at +80, the body at +120', (tester) async {
    await pumpProfileApp(
      tester,
      Routes.accountClosing,
      reducedMotion: false,
      settle: false,
    );
    await tester.pump();
    final megaphone = find.byType(IqIllustration);
    final title = find.text('Your account is closing');
    final body = find.text('Sign in within 30 days to undo.');
    await tester.pump(_ms * 79);
    expect(_opacity(tester, title), 0);
    expect(_opacity(tester, body), 0);
    await tester.pump(_ms * 81);
    expect(_opacity(tester, megaphone), closeTo(_eo(0.5), 0.02));
    expect(_opacity(tester, title), greaterThan(0));
    await tester.pumpAndSettle();
    expect(_opacity(tester, body), 1);
  });
}
