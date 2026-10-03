import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/app.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/device.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/entry/forgot_password_screen.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/notifications_ask_screen.dart';
import 'package:iqly_mobile/features/entry/password_screen.dart';
import 'package:iqly_mobile/features/entry/reset_link_sent_screen.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';
import 'package:iqly_mobile/features/entry/your_name_screen.dart';
import 'package:iqly_mobile/features/onboarding/done_screen.dart';
import 'package:iqly_mobile/features/onboarding/welcome_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/box_field.dart';
import 'package:iqly_mobile/ui/next_fab.dart';
import 'package:iqly_mobile/ui/provider_button.dart';
import 'package:iqly_mobile/ui/tip_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends DemoAuthService {
  _Auth({required this.oauthNew}) : super(delay: Duration.zero);

  final bool oauthNew;

  @override
  Future<AuthResult> continueWith(AuthProvider provider) async =>
      AuthResult.success(newAccount: oauthNew);
}

Future<ProviderContainer> _boot(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  String? start,
  bool oauthNew = true,
  DemoDeviceService? device,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  SharedPreferences.setMockInitialValues(prefs);
  final shared = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(shared),
      authServiceProvider.overrideWithValue(_Auth(oauthNew: oauthNew)),
      deviceServiceProvider.overrideWithValue(
        device ?? DemoDeviceService(delay: Duration.zero),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const IqlyApp()),
  );
  if (start == null) {
    await tester.pump(const Duration(seconds: 3));
  } else {
    container.read(routerProvider).go(start);
  }
  await tester.pumpAndSettle();
  return container;
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byType(IqNextFab));
  await tester.pumpAndSettle();
}

Future<void> _typeInto(WidgetTester tester, int index, String text) async {
  await tester.enterText(find.byType(EditableText).at(index), text);
  await tester.pump();
}

void main() {
  testWidgets('a new email signs up through name and password', (tester) async {
    final c = await _boot(tester);
    expect(find.byType(LandingScreen), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);

    await tester.enterText(find.byType(IqBoxField), 'tolu@example.com');
    await tester.pumpAndSettle();
    expect(find.text('Continue with Apple'), findsNothing);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(YourNameScreen), findsOneWidget);

    await _typeInto(tester, 0, 'Tolu');
    await _typeInto(tester, 1, 'Bello');
    await _next(tester);
    expect(find.byType(PasswordScreen), findsOneWidget);

    await _typeInto(tester, 0, 'short');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(PasswordScreen), findsOneWidget);
    expect(find.text('At least 8 characters'), findsOneWidget);

    await tester.tap(find.text('Show'));
    await tester.pump();
    expect(find.text('Hide'), findsOneWidget);

    await _typeInto(tester, 0, 'longenough');
    await _next(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(c.read(sessionProvider).signedIn, isTrue);
    expect(c.read(sessionProvider).onboardingDone, isFalse);
  });

  testWidgets('a known email signs in, through a password reset', (
    tester,
  ) async {
    final c = await _boot(tester);
    await tester.enterText(find.byType(IqBoxField), 'adaeze@example.com');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('adaeze@example.com'), findsOneWidget);

    await tester.tap(find.text('Forgot your password?'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.byType(ResetLinkSentScreen), findsOneWidget);
    expect(find.text('Sent to adaeze@example.com'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    await _typeInto(tester, 1, 'password');
    await _next(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(IqTipCard), findsNothing);
    expect(c.read(sessionProvider).onboardingDone, isTrue);
  });

  testWidgets('Sign in from the landing link, back returns', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(LandingScreen), findsOneWidget);
  });

  testWidgets('Apple: a new account goes to onboarding', (tester) async {
    await _boot(tester);
    await tester.tap(find.byType(IqProviderButton).first);
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('Google: a known account goes to Discover', (tester) async {
    await _boot(tester, oauthNew: false);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(IqTipCard), findsNothing);
  });

  testWidgets('notifications ask lands on Discover with the tip, once', (
    tester,
  ) async {
    final c = await _boot(
      tester,
      prefs: {'session.signedIn': true, 'session.onboardingDone': true},
      start: Routes.notificationsAsk,
    );
    expect(find.byType(NotificationsAskScreen), findsOneWidget);
    await tester.tap(find.text('Turn on notifications'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(IqTipCard), findsOneWidget);

    await tester.tap(find.text('OK, got it'));
    await tester.pumpAndSettle();
    expect(find.byType(IqTipCard), findsNothing);
    expect(c.read(sessionProvider).firstTipSeen, isTrue);

    c.read(routerProvider).go(Routes.notificationsAsk);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(IqTipCard), findsNothing);
  });

  testWidgets('the legal links open the shipped pages', (tester) async {
    final device = DemoDeviceService(delay: Duration.zero);
    await _boot(tester, device: device);
    final legal = find.textContaining('By continuing');
    final rect = tester.getRect(legal);
    await tester.tapAt(rect.bottomCenter - const Offset(0, 6));
    await tester.pump();
    expect(device.opened, [LegalLinks.privacy]);
  });

  testWidgets('back from the notifications ask returns to onboarding Done', (
    tester,
  ) async {
    await _boot(
      tester,
      prefs: {'session.signedIn': true},
      start: Routes.onboardingDone,
    );
    expect(find.byType(DoneScreen), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsAskScreen), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(DoneScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
