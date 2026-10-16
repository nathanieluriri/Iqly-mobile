import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/entry/entry_state.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';
import 'package:iqly_mobile/features/entry/verify_email_screen.dart';
import 'package:iqly_mobile/features/onboarding/welcome_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/banner.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/field.dart';

import 'entry_harness.dart';

String? _banner(WidgetTester tester) {
  final shown = tester
      .widgetList<IqBanner>(find.byType(IqBanner))
      .where((b) => b.visible);
  return shown.isEmpty ? null : shown.single.title;
}

bool _verifyOn(WidgetTester tester) => !tester
    .widget<IqButton>(find.widgetWithText(IqButton, 'Verify email'))
    .disabled;

IqFieldState? _fieldState(WidgetTester tester) => tester
    .widget<IqField>(
      find.byWidgetPredicate((w) => w is IqField && w.label == '6-digit code'),
    )
    .state;

Future<ProviderContainer> _open(
  WidgetTester tester, {
  String email = 'new@example.com',
}) => bootApp(
  tester,
  start: Routes.verifyEmail,
  prepare: (c) => c.read(entryDraftProvider.notifier).setEmail(email),
);

Future<void> _type(WidgetTester tester, String code) async {
  await typeInto(tester, 0, code);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Verify email stays off until six digits are in, and the sixth '
      'digit verifies a new account into onboarding', (tester) async {
    final c = await _open(tester);
    expect(
      find.text(
        'We sent a 6-digit code to new@example.com. It expires in 5 minutes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Didn’t get it? Send a new code in 1:00'), findsOneWidget);
    expect(_verifyOn(tester), isFalse);

    await _type(tester, '4829');
    expect(_verifyOn(tester), isFalse);

    await _type(tester, DemoAuthService.code);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(c.read(sessionProvider).signedIn, isTrue);
    expect(c.read(sessionProvider).onboardingDone, isFalse);
  });

  testWidgets('a wrong code shows the banner and the field in error, both gone '
      'on the next edit', (tester) async {
    await _open(tester);
    await _type(tester, '482951');
    expect(find.byType(VerifyEmailScreen), findsOneWidget);
    expect(
      _banner(tester),
      'That code isn’t right. Check the email and try again.',
    );
    expect(_fieldState(tester), IqFieldState.error);
    expect(_verifyOn(tester), isTrue);

    await _type(tester, '48295');
    expect(_banner(tester), isNull);
    expect(_fieldState(tester), isNot(IqFieldState.error));
  });

  final spent = {
    DemoAuthService.expiredCode:
        'That code has expired. Send a new one to keep going.',
    DemoAuthService.lockedCode:
        'Too many tries. Send a new code to keep going.',
  };
  for (final MapEntry(key: code, value: message) in spent.entries) {
    testWidgets('"$message" turns Verify email off until a new code is sent', (
      tester,
    ) async {
      await _open(tester);
      await _type(tester, code);
      expect(_banner(tester), message);
      expect(_verifyOn(tester), isFalse);
      expect(find.text('Need a new one?'), findsOneWidget);

      await tester.tap(find.text('Send a new code'));
      await tester.pumpAndSettle();
      expect(_banner(tester), isNull);
      expect(
        find.text('New code sent. You can send another in 1:00.'),
        findsOneWidget,
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        isEmpty,
      );

      await _type(tester, DemoAuthService.code);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  }

  testWidgets('a new code can go out once the minute is up', (tester) async {
    await _open(tester);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Didn’t get it? Send a new code in 0:30'), findsOneWidget);
    expect(find.text('Send a new code'), findsNothing);

    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('Didn’t get it?'), findsOneWidget);
    await tester.tap(find.text('Send a new code'));
    await tester.pumpAndSettle();
    expect(
      find.text('New code sent. You can send another in 1:00.'),
      findsOneWidget,
    );
  });

  testWidgets('signing in before verifying sends a code and verifies into '
      'Discover', (tester) async {
    final c = await bootApp(tester, start: Routes.signIn);
    expect(find.byType(SignInScreen), findsOneWidget);
    await typeInto(tester, 0, DemoAuthService.unverifiedEmail);
    await typeInto(tester, 1, 'whatever1');
    await tapNext(tester);
    expect(find.byType(VerifyEmailScreen), findsOneWidget);
    expect(
      find.textContaining(DemoAuthService.unverifiedEmail),
      findsOneWidget,
    );

    await _type(tester, DemoAuthService.code);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(c.read(sessionProvider).onboardingDone, isTrue);
  });
}
