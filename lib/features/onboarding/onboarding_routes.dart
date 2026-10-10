import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../router.dart';
import 'about_you_screen.dart';
import 'add_university_screen.dart';
import 'done_screen.dart';
import 'resume_screen.dart';
import 'welcome_screen.dart';
import 'what_you_like_screen.dart';
import 'where_you_live_screen.dart';
import 'where_you_studied_screen.dart';
import 'your_avatar_screen.dart';

/// Welcome, Resume and Done take over from another flow (the splash, sign
/// up, the last step), so they hand off; the steps and Add your university
/// push over their opener, which back returns to.
final onboardingRoutes = <RouteBase>[
  _handoff(Routes.onboarding, const WelcomeScreen()),
  _handoff(Routes.onboardingResume, const ResumeScreen()),
  _push(Routes.onboardingAboutYou, const AboutYouScreen()),
  _push(Routes.onboardingWhereYouLive, const WhereYouLiveScreen()),
  _push(Routes.onboardingWhereYouStudied, const WhereYouStudiedScreen()),
  GoRoute(
    path: Routes.onboardingAddUniversity,
    pageBuilder: (context, state) => pushPage(
      state,
      AddUniversityScreen(initialName: state.extra as String? ?? ''),
    ),
  ),
  _push(Routes.onboardingWhatYouLike, const WhatYouLikeScreen()),
  _push(Routes.onboardingYourAvatar, const YourAvatarScreen()),
  _handoff(Routes.onboardingDone, const DoneScreen()),
];

GoRoute _push(String path, Widget screen) => GoRoute(
  path: path,
  pageBuilder: (context, state) => pushPage(state, screen),
);

GoRoute _handoff(String path, Widget screen) => GoRoute(
  path: path,
  pageBuilder: (context, state) => handoffPage(state, screen),
);
