import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/discover/home_screen.dart';
import 'features/entry/forgot_password_screen.dart';
import 'features/entry/landing_screen.dart';
import 'features/entry/notifications_ask_screen.dart';
import 'features/entry/password_screen.dart';
import 'features/entry/reset_link_sent_screen.dart';
import 'features/entry/sign_in_screen.dart';
import 'features/entry/your_name_screen.dart';
import 'features/onboarding/onboarding_routes.dart';
import 'features/splash/splash_screen.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const landing = '/landing';
  static const home = '/home';
  static const yourName = '/sign-up/name';
  static const createPassword = '/sign-up/password';
  static const signIn = '/sign-in';
  static const forgotPassword = '/forgot-password';
  static const resetLinkSent = '/forgot-password/sent';
  static const notificationsAsk = '/turn-on-notifications';
  static const onboarding = '/onboarding';
  static const onboardingAboutYou = '/onboarding/about-you';
  static const onboardingWhereYouLive = '/onboarding/where-you-live';
  static const onboardingWhereYouStudied = '/onboarding/where-you-studied';
  static const onboardingWhatYouLike = '/onboarding/what-you-like';
  static const onboardingResume = '/onboarding/resume';
  static const onboardingDone = '/onboarding/done';
}

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: Routes.splash,
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.landing,
        pageBuilder: (context, state) =>
            _dissolve(state, const LandingScreen()),
      ),
      GoRoute(
        path: Routes.home,
        pageBuilder: (context, state) => _dissolve(state, const HomeScreen()),
      ),
      ..._entryRoutes,
      ...onboardingRoutes,
    ],
  ),
);

/// The splash hands off with a 0.4 s ease-out dissolve (Figma prototype).
CustomTransitionPage<void> _dissolve(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
    );

final _entryRoutes = [
  GoRoute(
    path: Routes.yourName,
    builder: (context, state) => const YourNameScreen(),
  ),
  GoRoute(
    path: Routes.createPassword,
    builder: (context, state) => const PasswordScreen(),
  ),
  GoRoute(
    path: Routes.signIn,
    builder: (context, state) => const SignInScreen(),
  ),
  GoRoute(
    path: Routes.forgotPassword,
    builder: (context, state) => const ForgotPasswordScreen(),
  ),
  GoRoute(
    path: Routes.resetLinkSent,
    builder: (context, state) => const ResetLinkSentScreen(),
  ),
  GoRoute(
    path: Routes.notificationsAsk,
    builder: (context, state) => const NotificationsAskScreen(),
  ),
];
