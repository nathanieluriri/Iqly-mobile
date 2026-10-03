import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/features/entry/entry_state.dart';
import 'package:iqly_mobile/features/entry/forgot_password_screen.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/notifications_ask_screen.dart';
import 'package:iqly_mobile/features/entry/password_screen.dart';
import 'package:iqly_mobile/features/entry/reset_link_sent_screen.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';
import 'package:iqly_mobile/features/entry/your_name_screen.dart';
import 'package:iqly_mobile/ui/box_field.dart';
import 'package:iqly_mobile/ui/next_fab.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'screen_golden.dart';

void main() {
  setUpAll(loadAppFonts);

  const email = 'adaeze@example.com';

  testWidgets('landing (227:10756)', (tester) async {
    await expectScreenGolden(tester, 'entry_landing', const LandingScreen());
  });

  testWidgets('landing email focused (231:11204)', (tester) async {
    await expectScreenGolden(
      tester,
      'entry_landing_email_focused',
      const LandingScreen(),
      keyboard: 260,
      act: (tester) async {
        await tester.enterText(find.byType(IqBoxField), 'adaeze@');
      },
    );
  });

  testWidgets('your name (227:10921)', (tester) async {
    await expectScreenGolden(
      tester,
      'entry_your_name',
      const YourNameScreen(),
      prepare: (c) => c.read(entryDraftProvider.notifier).setName('Adaeze', ''),
    );
  });

  testWidgets('password (227:10970)', (tester) async {
    await expectScreenGolden(tester, 'entry_password', const PasswordScreen());
  });

  testWidgets('sign in with email (227:11109)', (tester) async {
    await expectScreenGolden(
      tester,
      'entry_sign_in',
      const SignInScreen(),
      prepare: (c) => c.read(entryDraftProvider.notifier).setEmail(email),
      act: (tester) async {
        await tester.enterText(find.byType(EditableText).last, 'password');
      },
    );
  });

  testWidgets('forgot password (227:11157)', (tester) async {
    await expectScreenGolden(
      tester,
      'entry_forgot_password',
      const ForgotPasswordScreen(),
      prepare: (c) => c.read(entryDraftProvider.notifier).setEmail(email),
    );
  });

  testWidgets('reset link sent (227:11209)', (tester) async {
    await expectScreenGolden(
      tester,
      'entry_reset_link_sent',
      const ResetLinkSentScreen(),
      prepare: (c) => c.read(entryDraftProvider.notifier).setEmail(email),
    );
  });

  testWidgets('notifications (227:11263)', (tester) async {
    await expectScreenGolden(
      tester,
      'entry_notifications',
      const NotificationsAskScreen(),
    );
  });

  testWidgets('home first tip (227:11321)', (tester) async {
    await pumpApp(
      tester,
      Routes.home,
      prefs: signedInPrefs(firstTipSeen: false),
    );
    await expectMatchesGolden(
      find.byType(MaterialApp),
      'goldens/entry_home_first_tip.png',
    );
  });

  group('errors', () {
    final instant = [
      authServiceProvider.overrideWithValue(
        DemoAuthService(delay: Duration.zero),
      ),
    ];

    testWidgets('landing bad email (231:11204 with a BoxField error)', (
      tester,
    ) async {
      await expectScreenGolden(
        tester,
        'entry_landing_bad_email',
        const LandingScreen(),
        keyboard: 260,
        overrides: instant,
        act: (tester) async {
          await tester.enterText(find.byType(IqBoxField), 'adaeze@example');
          await tester.pumpAndSettle();
          await tester.tap(find.text('Continue'));
        },
      );
    });

    testWidgets('landing Apple failed (227:10756 with an Error banner)', (
      tester,
    ) async {
      await expectScreenGolden(
        tester,
        'entry_landing_apple_failed',
        const LandingScreen(),
        overrides: [
          authServiceProvider.overrideWithValue(
            DemoAuthService(
              delay: Duration.zero,
              socialFailure: AuthFailure.unknown,
            ),
          ),
        ],
        act: (tester) async {
          await tester.tap(find.text('Continue with Apple'));
        },
      );
    });

    testWidgets('sign in wrong password (227:11109, Field Error 58:894)', (
      tester,
    ) async {
      await expectScreenGolden(
        tester,
        'entry_sign_in_wrong_password',
        const SignInScreen(),
        overrides: instant,
        prepare: (c) => c.read(entryDraftProvider.notifier).setEmail(email),
        act: (tester) async {
          await tester.enterText(find.byType(EditableText).last, 'wrongpass');
          await tester.pumpAndSettle();
          await tester.tap(find.byType(IqNextFab));
        },
      );
    });

    testWidgets('forgot password bad email (227:11157, Field Error 58:894)', (
      tester,
    ) async {
      await expectScreenGolden(
        tester,
        'entry_forgot_password_bad_email',
        const ForgotPasswordScreen(),
        overrides: instant,
        prepare: (c) =>
            c.read(entryDraftProvider.notifier).setEmail('adaeze@example'),
        act: (tester) async {
          await tester.tap(find.text('Send reset link'));
        },
      );
    });
  });
}
