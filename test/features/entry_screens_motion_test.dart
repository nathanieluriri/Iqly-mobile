import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/features/entry/entry_copy.dart';
import 'package:iqly_mobile/features/entry/entry_state.dart';
import 'package:iqly_mobile/features/entry/forgot_password_screen.dart';
import 'package:iqly_mobile/features/entry/password_screen.dart';
import 'package:iqly_mobile/features/entry/reset_link_sent_screen.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';
import 'package:iqly_mobile/features/onboarding/welcome_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/next_fab.dart';
import 'package:iqly_mobile/ui/step_mark.dart';
import 'package:iqly_mobile/ui/top_bar.dart';

import 'entry_harness.dart';
import 'phone_keyboard.dart';

const _ms = Duration(milliseconds: 1);
const _light = 'HapticFeedbackType.lightImpact';
const _medium = 'HapticFeedbackType.mediumImpact';
const _success = 'HapticFeedbackType.successNotification';

double _eo(double t) => IqCurves.easeOut.transform(t);
double _ei(double t) => IqCurves.easeIn.transform(t);
double _eio(double t) => IqCurves.easeInOut.transform(t);

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

/// The step mark drawn in flight between two pages.
final _shuttle = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_Morph',
);

/// The widths of the mark's slots, in order.
List<double> _slots(WidgetTester tester, Finder mark) {
  final row = tester.renderObject<RenderFlex>(
    find.descendant(of: mark, matching: find.byType(Row)).first,
  );
  final widths = <double>[];
  var child = row.firstChild;
  while (child != null) {
    if (child.size.height == IqStepMark.ring) widths.add(child.size.width);
    child = (child.parentData! as FlexParentData).nextSibling;
  }
  return widths;
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
  }) {
    signUps++;
    return super.signUp(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
  }
}

void main() {
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  testWidgets(
    'Your name to Password: the chrome holds and the mark morphs while the '
    'title rides the push and the field trails it, the keyboard staying up',
    (tester) async {
      final haptics = recordHaptics(tester);
      await bootApp(tester, start: Routes.yourName, reduced: false);
      await tester.pumpAndSettle();
      await typeInto(tester, 0, 'Ada');
      await typeInto(tester, 1, 'Obi');
      final bar = tester.getTopLeft(find.byType(IqTopBar));
      final mark = tester.getTopLeft(find.byType(IqStepMark));
      final next = tester.getTopLeft(find.byType(IqNextFab));
      expect(_slots(tester, find.byType(IqStepMark)), [6, 44, 6]);

      await tester.tap(find.byType(IqNextFab));
      await _playTo(tester, _ms * 150);
      expect(tester.getTopLeft(find.byType(IqTopBar).last), bar);
      expect(tester.getTopLeft(_shuttle.last), mark);
      final grown = 6 + 38 * _eio(0.5);
      final slots = _slots(tester, _shuttle.last);
      expect(slots[0], 6);
      expect(slots[1], closeTo(50 - grown, 0.01));
      expect(slots[2], closeTo(grown, 0.01));
      expect(tester.getTopLeft(find.byType(IqNextFab).last), next);
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
      expect(_slots(tester, find.byType(IqStepMark)), [6, 6, 44]);
      expect(tester.getTopLeft(find.byType(IqStepMark)), mark);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(haptics, [_light]);
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
    expect(_slots(tester, mark), [6, 6, 44]);
    await tester.pump(_ms * 80);
    expect(_opacity(tester, title), 1);
  });

  testWidgets('Sign in to Forgot password: the back button holds while the '
      'bar title leaves over 120', (tester) async {
    final haptics = recordHaptics(tester);
    await bootApp(tester, start: Routes.signIn, reduced: false);
    await tester.pumpAndSettle();
    final bar = tester.getTopLeft(find.byType(IqTopBar));
    const title = 'Sign in with email';
    expect(_opacity(tester, find.text(title)), 1);

    await tester.tap(find.text('Forgot your password?'));
    await _playTo(tester, _ms * 60);
    expect(tester.getTopLeft(find.byType(IqTopBar).last), bar);
    expect(
      _opacity(tester, find.text(title).last),
      closeTo(1 - _ei(0.5), 0.02),
    );
    // Drawn in the app's own style, not the framework's fallback.
    expect(
      tester
          .renderObject<RenderParagraph>(find.text(title).last)
          .text
          .style
          ?.decoration,
      isNull,
    );
    await tester.pump(_ms * 60);
    expect(_opacity(tester, find.text(title).last), closeTo(0, 0.001));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.text(title), findsNothing);
    expect(haptics, isEmpty);
  });

  testWidgets('Sign in fails: the error haptic, and the Forgot row moves down '
      'with the help line instead of jumping', (tester) async {
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

    await tester.tap(find.byType(IqNextFab));
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump();
    expect(find.text(EntryCopy.signIn(AuthFailure.wrongCredentials)), findsOne);
    final start = tester.getTopLeft(forgot).dy;
    await tester.pump(_ms * 80);
    final mid = tester.getTopLeft(forgot).dy;
    await tester.pump(_ms * 100);
    final end = tester.getTopLeft(forgot).dy;
    final help = end - rest;
    expect(help, greaterThan(12));
    expect(start - rest, lessThan(help * 0.2));
    expect(mid - rest, closeTo(help * _eo(0.5), help * 0.08));
    expect(haptics, [_light, _medium]);
    await tester.pumpAndSettle();
  });

  testWidgets('Password works while the account is made: one call, then the '
      'success haptic and Welcome', (tester) async {
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

    await tester.tap(find.byType(IqNextFab));
    await tester.pump();
    await tester.pump(_ms * 100);
    expect(find.byKey(const ValueKey('spinner')), findsOneWidget);
    await tester.tap(find.byType(IqNextFab), warnIfMissed: false);
    await tester.pump(_ms * 100);
    expect(auth.signUps, 1);
    expect(haptics, [_light]);

    await tester.pump(_ms * 500);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(auth.signUps, 1);
    expect(haptics, [_light, _success]);
    expect(tester.testTextInput.isVisible, isFalse);
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
      if (leaving != null) expect(leaving, send);
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
      expect(haptics, [_light, _success]);
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
      expect(haptics, [_success]);
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
