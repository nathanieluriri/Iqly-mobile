import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/features/entry/entry_copy.dart';
import 'package:iqly_mobile/features/entry/entry_state.dart';
import 'package:iqly_mobile/features/entry/forgot_password_screen.dart';
import 'package:iqly_mobile/features/entry/password_screen.dart';
import 'package:iqly_mobile/features/entry/reset_link_sent_screen.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';
import 'package:iqly_mobile/features/entry/verify_email_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/step_mark.dart';
import 'package:iqly_mobile/ui/top_bar.dart';

import 'entry_harness.dart';
import 'phone_keyboard.dart';

const _ms = Duration(milliseconds: 1);
const _light = 'HapticFeedbackType.lightImpact';
const _medium = 'HapticFeedbackType.mediumImpact';
const _success = 'HapticFeedbackType.successNotification';

double _eo(double t) => IqCurves.easeOut.transform(t);

/// The product of every fade above [finder].
double _opacity(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  for (final widget in tester.widgetList(
    find.ancestor(
      of: finder,
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

/// Starts a push or pop and plays it to [at] of its run.
Future<void> _playTo(WidgetTester tester, Duration at) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(at);
}

class _SlowAuth extends DemoAuthService {
  _SlowAuth() : super(delay: const Duration(milliseconds: 600));

  int signUps = 0;

  @override
  Future<AuthResult> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? inviteCode,
  }) {
    signUps++;
    return super.signUp(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      inviteCode: inviteCode,
    );
  }
}

void main() {
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  testWidgets(
    'Your name to Password: the chrome holds while the title rides the push '
    'and the field trails it, the keyboard staying up',
    (tester) async {
      final haptics = recordHaptics(tester);
      await bootApp(tester, start: Routes.yourName, reduced: false);
      await tester.pumpAndSettle();
      await typeInto(tester, 0, 'Ada');
      await typeInto(tester, 1, 'Obi');
      final bar = tester.getTopLeft(find.byType(IqTopBar));
      final mark = tester.getTopLeft(find.byType(IqStepMark));
      final next = tester.getTopLeft(find.byType(IqButton));

      await tester.tap(find.byType(IqButton));
      await _playTo(tester, _ms * 150);
      expect(tester.getTopLeft(find.byType(IqTopBar).last), bar);
      expect(tester.getTopLeft(find.byType(IqStepMark).last), mark);
      expect(
        (tester.getTopLeft(find.byType(IqButton).last) - next).distance,
        lessThan(0.01),
      );
      expect(
        tester.getTopLeft(find.text('Create a password')).dx,
        closeTo(16 + 24 * (1 - _eo(0.5)), 0.5),
      );
      double trail() =>
          tester.getTopLeft(find.byType(EditableText).last).dx -
          tester.getTopLeft(find.text('Create a password')).dx;
      final midTrail = trail();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.pump(_ms * 150);
      await tester.pumpAndSettle();
      expect(find.byType(PasswordScreen), findsOneWidget);
      const lag = 40 / 300;
      final own = _eo((0.5 - lag) / (1 - lag));
      expect(midTrail - trail(), closeTo(24 * (_eo(0.5) - own), 0.5));
      expect(
        tester.widget<IqStepMark>(find.byType(IqStepMark)).step,
        IqStepMarkStep.threeOfThree,
      );
      expect(tester.getTopLeft(find.byType(IqStepMark)), mark);
      expect(find.text('Create account'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(haptics, [_medium]);
    },
  );

  testWidgets('reduced motion: Password and its chrome crossfade in place '
      'over 150', (tester) async {
    final container = await bootApp(tester, start: Routes.yourName);
    container.read(routerProvider).push(Routes.createPassword);
    await _playTo(tester, _ms * 75);
    final title = find.text('Create a password');
    expect(tester.getTopLeft(title).dx, 16);
    expect(_opacity(tester, title), closeTo(_eo(0.5), 0.02));
    final mark = find.byType(IqStepMark).last;
    expect(_opacity(tester, mark), closeTo(_eo(0.5), 0.02));
    await tester.pump(_ms * 80);
    expect(_opacity(tester, title), 1);
  });

  testWidgets('Sign in to Forgot password: the back button and the action '
      'button hold still', (tester) async {
    final haptics = recordHaptics(tester);
    await bootApp(tester, start: Routes.signIn, reduced: false);
    await tester.pumpAndSettle();
    final bar = tester.getTopLeft(find.byType(IqTopBar));
    final action = tester.getTopLeft(find.byType(IqButton));

    await tester.tap(find.text('Forgot your password?'));
    await _playTo(tester, _ms * 60);
    expect(tester.getTopLeft(find.byType(IqTopBar).last), bar);
    final held = tester.getTopLeft(find.byType(IqButton).last) - action;
    expect(held.distance, lessThan(0.01));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
    expect(haptics, [_light]);
  });

  testWidgets('Sign in fails: the error haptic, and the Forgot row moves down '
      'with the banner instead of jumping', (tester) async {
    final haptics = recordHaptics(tester);
    await bootApp(
      tester,
      start: Routes.signIn,
      reduced: false,
      prepare: (c) =>
          c.read(entryDraftProvider.notifier).setEmail(DemoData.user.email),
    );
    await tester.pumpAndSettle();
    await typeInto(tester, 1, 'not-the-one');
    final forgot = find.text('Forgot your password?');
    final rest = tester.getTopLeft(forgot).dy;

    await tester.tap(find.byType(IqButton));
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump();
    expect(find.text(EntryCopy.signIn(AuthFailure.wrongCredentials)), findsOne);
    final start = tester.getTopLeft(forgot).dy;
    await tester.pump(_ms * 120);
    final mid = tester.getTopLeft(forgot).dy;
    await tester.pump(_ms * 120);
    await tester.pump();
    final end = tester.getTopLeft(forgot).dy;
    final banner = end - rest;
    expect(banner, greaterThan(60));
    expect(start - rest, lessThan(banner * 0.2));
    expect(mid - rest, closeTo(banner * _eo(0.5), banner * 0.1));
    expect(haptics, [_medium, _medium]);
    await tester.pumpAndSettle();
  });

  testWidgets('Sign in keeps its spinner while Discover dissolves in over '
      'it', (tester) async {
    await bootApp(
      tester,
      start: Routes.signIn,
      reduced: false,
      auth: _SlowAuth(),
      prepare: (c) =>
          c.read(entryDraftProvider.notifier).setEmail(DemoData.user.email),
    );
    await tester.pumpAndSettle();
    await typeInto(tester, 1, DemoAuthService.password);
    await tester.tap(find.byType(IqButton));
    await tester.pump();
    final signIn = find.byType(SignInScreen, skipOffstage: false);
    var handedOver = false;
    for (var frame = 0; frame < 80 && signIn.evaluate().isNotEmpty; frame++) {
      await tester.pump(_ms * 16);
      if (signIn.evaluate().isEmpty) break;
      final button = tester.widget<IqButton>(
        find.descendant(of: signIn, matching: find.byType(IqButton)),
      );
      expect(button.loading, isTrue, reason: 'frame $frame');
      handedOver |=
          GoRouter.of(tester.element(signIn)).state.uri.path == Routes.home;
    }
    expect(handedOver, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('Password works while the account is made: one call, then the '
      'success haptic and Verify email', (tester) async {
    final haptics = recordHaptics(tester);
    final auth = _SlowAuth();
    await bootApp(
      tester,
      start: Routes.createPassword,
      reduced: false,
      auth: auth,
      prepare: (c) {
        c.read(entryDraftProvider.notifier)
          ..setEmail('new@example.com')
          ..setName('Ada', 'Obi');
      },
    );
    await tester.pumpAndSettle();
    await typeInto(tester, 0, 'boldthinker1');

    await tester.tap(find.byType(IqButton));
    await tester.pump();
    await tester.pump(_ms * 100);
    expect(find.byKey(const ValueKey('spinner')), findsOneWidget);
    await tester.tap(find.byType(IqButton), warnIfMissed: false);
    await tester.pump(_ms * 100);
    expect(auth.signUps, 1);
    expect(haptics, [_medium]);

    await tester.pump(_ms * 500);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(VerifyEmailScreen), findsOneWidget);
    expect(auth.signUps, 1);
    expect(haptics, [_medium, _success]);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('Forgot password to Reset link sent and back to Sign in: no '
      'page lays out against the keyboard as it comes or goes', (tester) async {
    await bootApp(tester, start: Routes.signIn, reduced: false);
    final keyboard = PhoneKeyboard(tester);
    await keyboard.until(() => keyboard.inset == PhoneKeyboard.height);
    await tester.tap(find.text('Forgot your password?'));
    await keyboard.frames(40);
    await tester.enterText(find.byType(EditableText), DemoData.user.email);
    await keyboard.frames(10);
    expect(keyboard.inset, PhoneKeyboard.height);

    double? top(String label) {
      final found = find.text(label);
      return found.evaluate().isEmpty ? null : tester.getTopLeft(found).dy;
    }

    final send = top('Send reset link')!;
    await tester.tap(find.text('Send reset link'));
    double? open;
    for (var i = 0; i < 40; i++) {
      await keyboard.frame();
      final leaving = top('Send reset link');
      // The press sink scales the button's paint, never its layout.
      if (leaving != null) expect(leaving, closeTo(send, 1));
      final coming = top('Open email app');
      if (coming != null) {
        open ??= coming;
        expect(coming, open);
      }
    }
    expect(keyboard.inset, 0);
    expect(find.byType(ResetLinkSentScreen), findsOneWidget);
    expect(
      find.byType(ForgotPasswordScreen, skipOffstage: false),
      findsOneWidget,
    );

    // Sign in takes its field back, and its keyboard rises as this page
    // leaves.
    await tester.tap(find.text('Sign in'));
    for (var i = 0; i < 30; i++) {
      await keyboard.frame();
      final leaving = top('Open email app');
      if (leaving != null) expect(leaving, open);
    }
    expect(find.byType(ResetLinkSentScreen), findsNothing);
    expect(keyboard.inset, PhoneKeyboard.height);
  });

  group('Reset link sent (spec 6.8)', () {
    Future<void> openSent(WidgetTester tester) async {
      await bootApp(
        tester,
        start: Routes.signIn,
        reduced: false,
        prepare: (c) =>
            c.read(entryDraftProvider.notifier).setEmail(DemoData.user.email),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot your password?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      await tester.pump(Duration.zero);
      await tester.pump();
      expect(find.byType(ResetLinkSentScreen), findsOneWidget);
    }

    testWidgets('the beats land in order: title, Sent to, Remembered', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await openSent(tester);
      final title = find.text('Check your email');
      final sent = find.textContaining('Sent to');
      final remembered = find.text('Remembered?');
      await tester.pump();
      expect(_opacity(tester, title), 0);
      await tester.pump(_ms * 150);
      expect(_opacity(tester, title), inExclusiveRange(0, 1));
      expect(_opacity(tester, sent), lessThan(_opacity(tester, title)));
      expect(_opacity(tester, remembered), 0);
      await tester.pumpAndSettle();
      for (final finder in [title, sent, remembered]) {
        expect(_opacity(tester, finder), 1);
      }
      expect(haptics, [_light, _medium, _success]);
    });

    testWidgets('Resend rolls the Sent to line once and plays success', (
      tester,
    ) async {
      await openSent(tester);
      await tester.pumpAndSettle();
      final haptics = recordHaptics(tester);
      await tester.tap(find.text('Resend link'));
      await tester.pump();
      await tester.pump();
      await tester.pump(_ms * 80);
      final sent = find.textContaining('Sent to');
      expect(sent, findsNWidgets(2));
      final leaving = tester.getTopLeft(sent.first).dy;
      final coming = tester.getTopLeft(sent.last).dy;
      expect(leaving, lessThan(coming));
      await tester.pumpAndSettle();
      expect(sent, findsOneWidget);
      expect(haptics, [_light, _success]);
    });

    testWidgets('Sign in pops only this page back onto Sign in', (
      tester,
    ) async {
      await openSent(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await _playTo(tester, _ms * 120);
      expect(find.byType(ForgotPasswordScreen), findsNothing);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(ResetLinkSentScreen)).dx,
        closeTo(24 * (1 - _eo(0.5)), 0.5),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ResetLinkSentScreen), findsNothing);
      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });
}
