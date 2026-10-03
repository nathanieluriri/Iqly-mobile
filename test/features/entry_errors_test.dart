import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/features/entry/entry_copy.dart';
import 'package:iqly_mobile/features/entry/entry_state.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/password_screen.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';
import 'package:iqly_mobile/features/entry/your_name_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/box_field.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/field.dart';
import 'package:iqly_mobile/ui/next_fab.dart';

import 'entry_harness.dart';

const _medium = 'HapticFeedbackType.mediumImpact';

IqField _field(WidgetTester tester, String label) => tester.widget<IqField>(
  find.byWidgetPredicate((w) => w is IqField && w.label == label),
);

IqBoxField _box(WidgetTester tester) =>
    tester.widget<IqBoxField>(find.byType(IqBoxField));

bool _buttonOn(WidgetTester tester, String label) =>
    !tester.widget<IqButton>(find.widgetWithText(IqButton, label)).disabled;

bool _nextOn(WidgetTester tester) =>
    tester.widget<IqNextFab>(find.byType(IqNextFab)).state ==
    IqNextFabState.enabled;

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  group('landing', () {
    testWidgets('Continue is on once anything is typed', (tester) async {
      await bootApp(tester);
      await tester.enterText(find.byType(IqBoxField), 'a');
      await tester.pumpAndSettle();
      expect(_buttonOn(tester, 'Continue'), isTrue);
    });

    testWidgets('a bad email shows on submit and clears on edit', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await bootApp(tester);
      await tester.enterText(find.byType(IqBoxField), 'adaeze@example');
      await tester.pumpAndSettle();
      expect(find.text(EntryCopy.badEmail), findsNothing);

      await _tapText(tester, 'Continue');
      expect(find.byType(LandingScreen), findsOneWidget);
      expect(find.text(EntryCopy.badEmail), findsOneWidget);
      expect(_box(tester).state, IqBoxFieldState.error);
      // The refusal lands with the tap, so it plays in the commit's place.
      expect(haptics, [_medium]);

      await _tapText(tester, 'Continue');
      expect(haptics, [_medium, _medium]);

      await tester.tap(find.byType(IqBoxField));
      await tester.pumpAndSettle();
      expect(find.text(EntryCopy.badEmail), findsOneWidget);

      await tester.enterText(find.byType(IqBoxField), 'adaeze@example.');
      await tester.pumpAndSettle();
      expect(find.text(EntryCopy.badEmail), findsNothing);
      expect(_box(tester).state, isNull);
    });

    testWidgets('offline while looking up the email', (tester) async {
      await bootApp(tester);
      await tester.enterText(
        find.byType(IqBoxField),
        DemoAuthService.offlineEmail,
      );
      await tester.pumpAndSettle();
      await _tapText(tester, 'Continue');
      expect(find.byType(LandingScreen), findsOneWidget);
      expect(find.text(EntryCopy.offline), findsOneWidget);
    });

    for (final provider in AuthProvider.values) {
      final button = provider == AuthProvider.apple
          ? 'Continue with Apple'
          : 'Continue with Google';
      testWidgets('${provider.name} failure drops the banner in', (
        tester,
      ) async {
        final haptics = recordHaptics(tester);
        await bootApp(
          tester,
          auth: DemoAuthService(
            delay: Duration.zero,
            socialFailure: AuthFailure.unknown,
          ),
        );
        await _tapText(tester, button);
        expect(find.byType(LandingScreen), findsOneWidget);
        expect(find.text(EntryCopy.social(provider)), findsOneWidget);
        expect(haptics, [_medium]);

        await tester.tap(find.byType(IqBoxField));
        await tester.pumpAndSettle();
        expect(find.text(EntryCopy.social(provider)), findsNothing);
      });
    }

    testWidgets('a cancelled Apple sheet says nothing', (tester) async {
      final haptics = recordHaptics(tester);
      await bootApp(
        tester,
        auth: DemoAuthService(
          delay: Duration.zero,
          socialFailure: AuthFailure.cancelled,
        ),
      );
      await _tapText(tester, 'Continue with Apple');
      expect(find.byType(LandingScreen), findsOneWidget);
      expect(find.text(EntryCopy.social(AuthProvider.apple)), findsNothing);
      expect(haptics, isEmpty);
    });
  });

  group('sign in', () {
    Future<void> submit(
      WidgetTester tester,
      String email,
      String password,
    ) async {
      await typeInto(tester, 0, email);
      await typeInto(tester, 1, password);
      await tapNext(tester);
    }

    testWidgets('Next is on once both fields hold something', (tester) async {
      await bootApp(tester, start: Routes.signIn);
      expect(_nextOn(tester), isFalse);
      await typeInto(tester, 0, 'a');
      expect(_nextOn(tester), isFalse);
      await typeInto(tester, 1, 'b');
      expect(_nextOn(tester), isTrue);
    });

    testWidgets('a bad email shows on EMAIL and clears on edit', (
      tester,
    ) async {
      await bootApp(tester, start: Routes.signIn);
      await submit(tester, 'adaeze@', DemoAuthService.password);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(_field(tester, 'Email').state, IqFieldState.error);
      expect(_field(tester, 'Email').help, EntryCopy.badEmail);
      expect(_field(tester, 'Password').state, isNot(IqFieldState.error));

      await typeInto(tester, 0, 'adaeze@example.com');
      expect(find.text(EntryCopy.badEmail), findsNothing);
      expect(_field(tester, 'Email').state, isNot(IqFieldState.error));
    });

    final cases = {
      'wrong password': ('adaeze@example.com', 'wrongpass'),
      'too many tries': (DemoAuthService.lockedEmail, 'whatever1'),
      'not verified': (DemoAuthService.unverifiedEmail, 'whatever1'),
      'offline': (DemoAuthService.offlineEmail, 'whatever1'),
      'anything else': (DemoAuthService.brokenEmail, 'whatever1'),
    };
    final expected = {
      'wrong password': 'That email and password don’t match. Try again.',
      'too many tries': 'Too many tries. Wait a minute, then try again.',
      'not verified': 'Verification email sent. Please check your inbox.',
      'offline': 'You’re offline. Check your connection and try again.',
      'anything else': 'Login failed. Please try again.',
    };
    for (final MapEntry(key: name, value: (email, password)) in cases.entries) {
      testWidgets('$name shows on PASSWORD', (tester) async {
        final haptics = recordHaptics(tester);
        await bootApp(tester, start: Routes.signIn);
        await submit(tester, email, password);
        expect(find.byType(SignInScreen), findsOneWidget);
        expect(find.text(expected[name]!), findsOneWidget);
        expect(_field(tester, 'Password').state, IqFieldState.error);
        expect(_field(tester, 'Password').help, expected[name]);
        expect(haptics, [_medium]);
      });
    }

    testWidgets('a password error clears when the password changes', (
      tester,
    ) async {
      await bootApp(tester, start: Routes.signIn);
      await submit(tester, 'adaeze@example.com', 'wrongpass');
      const wrong = 'That email and password don’t match. Try again.';
      expect(find.text(wrong), findsOneWidget);

      await tester.tap(find.byType(EditableText).at(1));
      await tester.pumpAndSettle();
      expect(find.text(wrong), findsOneWidget);

      await typeInto(tester, 1, 'wrongpas');
      expect(find.text(wrong), findsNothing);
      expect(_field(tester, 'Password').state, isNot(IqFieldState.error));
    });
  });

  group('sign up password', () {
    Future<void> boot(WidgetTester tester, String email) => bootApp(
      tester,
      start: Routes.createPassword,
      prepare: (c) {
        c.read(entryDraftProvider.notifier)
          ..setEmail(email)
          ..setName('Tolu', 'Bello');
      },
    );

    testWidgets('Next is on once anything is typed; 8 is checked on submit', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await boot(tester, 'tolu@example.com');
      expect(_nextOn(tester), isFalse);
      await typeInto(tester, 0, 'short');
      expect(_nextOn(tester), isTrue);
      expect(_field(tester, 'Password').state, isNot(IqFieldState.error));

      await tapNext(tester);
      expect(find.byType(PasswordScreen), findsOneWidget);
      expect(_field(tester, 'Password').state, IqFieldState.error);
      expect(_field(tester, 'Password').help, 'At least 8 characters');
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(haptics, [_medium]);

      await typeInto(tester, 0, 'shorter');
      expect(_field(tester, 'Password').state, isNot(IqFieldState.error));
      expect(find.text('At least 8 characters'), findsOneWidget);
    });

    testWidgets('a taken email goes to Sign in with it filled', (tester) async {
      await boot(tester, DemoAuthService.takenEmail);
      await typeInto(tester, 0, 'longenough');
      await tapNext(tester);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text(DemoAuthService.takenEmail), findsOneWidget);
      expect(find.text(ShippedCopy.signUpFailed), findsNothing);
    });

    testWidgets('offline', (tester) async {
      await boot(tester, DemoAuthService.offlineEmail);
      await typeInto(tester, 0, 'longenough');
      await tapNext(tester);
      expect(find.byType(PasswordScreen), findsOneWidget);
      expect(_field(tester, 'Password').help, EntryCopy.offline);
    });

    testWidgets('anything else', (tester) async {
      await boot(tester, DemoAuthService.brokenEmail);
      await typeInto(tester, 0, 'longenough');
      await tapNext(tester);
      expect(find.byType(PasswordScreen), findsOneWidget);
      expect(
        _field(tester, 'Password').help,
        'Sign-up failed. Please try again.',
      );
      expect(find.text('At least 8 characters'), findsOneWidget);
    });
  });

  group('forgot password', () {
    Future<void> send(WidgetTester tester, String email) async {
      await typeInto(tester, 0, email);
      await _tapText(tester, 'Send reset link');
    }

    testWidgets('Send reset link is on once anything is typed', (tester) async {
      await bootApp(tester, start: Routes.forgotPassword);
      expect(_buttonOn(tester, 'Send reset link'), isFalse);
      await typeInto(tester, 0, 'a');
      expect(_buttonOn(tester, 'Send reset link'), isTrue);
    });

    testWidgets('a bad email shows on submit and clears on edit', (
      tester,
    ) async {
      await bootApp(tester, start: Routes.forgotPassword);
      await send(tester, 'adaeze.example.com');
      expect(_field(tester, 'Email').state, IqFieldState.error);
      expect(_field(tester, 'Email').help, EntryCopy.badEmail);
      await typeInto(tester, 0, 'adaeze@example.com');
      expect(find.text(EntryCopy.badEmail), findsNothing);
    });

    testWidgets('offline', (tester) async {
      await bootApp(tester, start: Routes.forgotPassword);
      await send(tester, DemoAuthService.offlineEmail);
      expect(_field(tester, 'Email').help, EntryCopy.offline);
    });

    testWidgets('anything else', (tester) async {
      await bootApp(tester, start: Routes.forgotPassword);
      await send(tester, DemoAuthService.brokenEmail);
      expect(
        _field(tester, 'Email').help,
        'Could not send reset email. Please try again.',
      );
    });
  });

  testWidgets('Your name keeps Next on once both names are typed', (
    tester,
  ) async {
    await bootApp(tester, start: Routes.yourName);
    expect(find.byType(YourNameScreen), findsOneWidget);
    await typeInto(tester, 0, 'T');
    expect(_nextOn(tester), isFalse);
    await typeInto(tester, 1, 'B');
    expect(_nextOn(tester), isTrue);
  });
}
