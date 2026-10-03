import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/discover/home_screen.dart';
import 'features/entry/landing_screen.dart';
import 'features/splash/splash_screen.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const landing = '/landing';
  static const home = '/home';
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
