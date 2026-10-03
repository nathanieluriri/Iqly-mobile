import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/theme.dart';
import 'about_you_screen.dart';
import 'done_screen.dart';
import 'resume_screen.dart';
import 'welcome_screen.dart';
import 'what_you_like_screen.dart';
import 'where_you_live_screen.dart';
import 'where_you_studied_screen.dart';

/// Figma transitions inside first run are Instant; Welcome and Resume are
/// also launch targets, so they take the splash's 0.4 s dissolve.
final onboardingRoutes = <RouteBase>[
  _fade(Routes.onboarding, const WelcomeScreen()),
  _fade(Routes.onboardingResume, const ResumeScreen()),
  _instant(Routes.onboardingAboutYou, const AboutYouScreen()),
  _instant(Routes.onboardingWhereYouLive, const WhereYouLiveScreen()),
  _instant(Routes.onboardingWhereYouStudied, const WhereYouStudiedScreen()),
  _instant(Routes.onboardingWhatYouLike, const WhatYouLikeScreen()),
  _instant(Routes.onboardingDone, const DoneScreen()),
  _instant(Routes.notificationsAsk, const _NotificationsAskPlaceholder()),
];

GoRoute _instant(String path, Widget screen) => GoRoute(
  path: path,
  pageBuilder: (context, state) =>
      NoTransitionPage<void>(key: state.pageKey, child: screen),
);

GoRoute _fade(String path, Widget screen) => GoRoute(
  path: path,
  pageBuilder: (context, state) => CustomTransitionPage<void>(
    key: state.pageKey,
    child: screen,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 400),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
  ),
);

/// Row B0 owns the Notifications ask; this stands in until that branch lands.
class _NotificationsAskPlaceholder extends StatelessWidget {
  const _NotificationsAskPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: IqColors.bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(IqSpace.s4),
          child: Text('Notifications', style: IqText.display),
        ),
      ),
    );
  }
}
