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
import 'package:iqly_mobile/ui/banner.dart';

import 'entry_harness.dart';

const _light = 'HapticFeedbackType.lightImpact';
const _medium = 'HapticFeedbackType.mediumImpact';

IqField _field(WidgetTester tester, String label) => tester.widget<IqField>(
  find.byWidgetPredicate((w) => w is IqField && w.label == label),
);

IqBoxField _box(WidgetTester tester) =>
    tester.widget<IqBoxField>(find.byType(IqBoxField));

bool _buttonOn(WidgetTester tester, String label) =>
    !tester.widget<IqButton>(find.widgetWithText(IqButton, label)).disabled;

/// The error banner's words, null while it is folded away.
String? _banner(WidgetTester tester) {
  final shown = tester
      .widgetList<IqBanner>(find.byType(IqBanner))
      .where((b) => b.visible);
  return shown.isEmpty ? null : shown.single.title;
}

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

    testWidgets('a bad email drops the banner in and it clears on edit '
        '(480:20014)', (tester) async {
      final haptics = recordHaptics(tester);
      await bootApp(tester);
      await tester.enterText(find.byType(IqBoxField), 'adaeze@');
      await tester.pumpAndSettle();
      expect(_banner(tester), isNull);

      await _tapText(tester, 'Continue');
      expect(find.byType(LandingScreen), findsOneWidget);
      expect(_banner(tester), EntryCopy.badEmail);
      expect(_box(tester).state, isNull);
      // The refusal lands with the tap, so it plays in the commit's place.
      expect(haptics, [_medium]);

      await tester.tap(find.byType(IqBoxField));
      await tester.pumpAndSettle();
      expect(_banner(tester), EntryCopy.badEmail);

      await tester.enterText(find.byType(IqBoxField), 'adaeze@example.');
      await tester.pumpAndSettle();
      expect(_banner(tester), isNull);
    });

    testWidgets('a known email offers Sign in with it filled (480:19948)', (
      tester,
    ) async {
      await bootApp(tester);
      await tester.enterText(find.byType(IqBoxField), 'adaeze@example.com');
      await tester.pumpAndSettle();
      await _tapText(tester, 'Continue');
      expect(find.byType(LandingScreen), findsOneWidget);
      expect(_banner(tester), EntryCopy.emailRegistered);

      await tester.tap(
        find.descendant(
          of: find.byType(IqBanner),
          matching: find.text('Sign in'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text('adaeze@example.com'), findsOneWidget);
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
      expect(_banner(tester), EntryCopy.offline);
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
        expect(_banner(tester), EntryCopy.social(provider));
        expect(haptics, [_medium], reason: 'the failure replaces the tap');

        await tester.tap(find.byType(IqBoxField));
        await tester.pumpAndSettle();
        expect(_banner(tester), isNull);
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
      expect(_banner(tester), isNull);
      expect(haptics, [_light]);
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

    testWidgets('an empty field takes the focus and nothing is sent', (
      tester,
    ) async {
      await bootApp(tester, start: Routes.signIn);
      await typeInto(tester, 0, 'adaeze@example.com');
      await tapNext(tester);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(_banner(tester), isNull);
      final password = tester.widget<EditableText>(
        find.byType(EditableText).at(1),
      );
      expect(password.focusNode.hasFocus, isTrue);
    });

    testWidgets('a bad email drops the banner in and clears on edit', (
      tester,
    ) async {
      await bootApp(tester, start: Routes.signIn);
      await submit(tester, 'adaeze@', DemoAuthService.password);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(_banner(tester), EntryCopy.badEmail);

      await typeInto(tester, 0, 'adaeze@example.com');
      await tester.pumpAndSettle();
      expect(_banner(tester), isNull);
    });

    final cases = {
      'wrong password': ('adaeze@example.com', 'wrongpass'),
      'too many tries': (DemoAuthService.lockedEmail, 'whatever1'),
      'offline': (DemoAuthService.offlineEmail, 'whatever1'),
      'anything else': (DemoAuthService.brokenEmail, 'whatever1'),
    };
    final expected = {
      'wrong password': "That password doesn't match. Try again or reset it.",
      'too many tries': 'Too many tries. Wait a minute, then try again.',
      'offline': 'You’re offline. Check your connection and try again.',
      'anything else': 'Login failed. Please try again.',
    };
    for (final MapEntry(key: name, value: (email, password)) in cases.entries) {
      testWidgets('$name shows in the banner (480:19882)', (tester) async {
        final haptics = recordHaptics(tester);
        await bootApp(tester, start: Routes.signIn);
        await submit(tester, email, password);
        expect(find.byType(SignInScreen), findsOneWidget);
        expect(_banner(tester), expected[name]);
        expect(_field(tester, 'Password').state, isNot(IqFieldState.error));
        expect(haptics, [_medium]);
      });
    }

    testWidgets('the banner goes when the password changes', (tester) async {
      await bootApp(tester, start: Routes.signIn);
      await submit(tester, 'adaeze@example.com', 'wrongpass');
      expect(_banner(tester), expected['wrong password']);

      await tester.tap(find.byType(EditableText).at(1));
      await tester.pumpAndSettle();
      expect(_banner(tester), expected['wrong password']);

      await typeInto(tester, 1, 'wrongpas');
      await tester.pumpAndSettle();
      expect(_banner(tester), isNull);
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

    testWidgets('8 is checked on submit, under the field', (tester) async {
      final haptics = recordHaptics(tester);
      await boot(tester, 'tolu@example.com');
      await typeInto(tester, 0, 'short');
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
      expect(_banner(tester), isNull);
    });

    testWidgets('offline', (tester) async {
      await boot(tester, DemoAuthService.offlineEmail);
      await typeInto(tester, 0, 'longenough');
      await tapNext(tester);
      expect(find.byType(PasswordScreen), findsOneWidget);
      expect(_banner(tester), EntryCopy.offline);
    });

    testWidgets('anything else', (tester) async {
      await boot(tester, DemoAuthService.brokenEmail);
      await typeInto(tester, 0, 'longenough');
      await tapNext(tester);
      expect(find.byType(PasswordScreen), findsOneWidget);
      expect(_banner(tester), 'Sign-up failed. Please try again.');
      expect(find.text('At least 8 characters'), findsOneWidget);
    });
  });

  group('forgot password', () {
    Future<void> send(WidgetTester tester, String email) async {
      await typeInto(tester, 0, email);
      await _tapText(tester, 'Send reset link');
    }

    testWidgets('a bad email drops the banner in and clears on edit', (
      tester,
    ) async {
      await bootApp(tester, start: Routes.forgotPassword);
      await send(tester, 'adaeze.example.com');
      expect(_banner(tester), EntryCopy.badEmail);
      await typeInto(tester, 0, 'adaeze@example.com');
      await tester.pumpAndSettle();
      expect(_banner(tester), isNull);
    });

    testWidgets('offline', (tester) async {
      await bootApp(tester, start: Routes.forgotPassword);
      await send(tester, DemoAuthService.offlineEmail);
      expect(_banner(tester), EntryCopy.offline);
    });

    testWidgets('anything else', (tester) async {
      await bootApp(tester, start: Routes.forgotPassword);
      await send(tester, DemoAuthService.brokenEmail);
      expect(_banner(tester), 'Could not send reset email. Please try again.');
    });
  });

  testWidgets('Your name stays until both names are typed', (tester) async {
    await bootApp(tester, start: Routes.yourName);
    expect(find.byType(YourNameScreen), findsOneWidget);
    await typeInto(tester, 0, 'T');
    await tapNext(tester);
    expect(find.byType(YourNameScreen), findsOneWidget);
    await typeInto(tester, 1, 'B');
    await tapNext(tester);
    expect(find.byType(PasswordScreen), findsOneWidget);
  });
}
