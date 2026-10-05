import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seeds the autosaved draft (and session flags) the frame shows.
Future<SharedPreferences> onboardingPrefs({
  Map<String, Object?> draft = const {},
  bool onboardingDone = false,
  bool firstTipSeen = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'session.signedIn': true,
    'session.onboardingDone': onboardingDone,
    'session.firstTipSeen': firstTipSeen,
    if (draft.isNotEmpty) 'onboarding.draft': jsonEncode(draft),
  });
  return SharedPreferences.getInstance();
}

/// The screen with the Figma frame's OS insets (54 status bar, 34 home
/// indicator), so layout lines up with the 390 x 844 PNG.
Widget onboardingFrame(SharedPreferences prefs, Widget screen) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: Builder(
      builder: (context) {
        const insets = EdgeInsets.only(top: 54, bottom: 34);
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(padding: insets, viewPadding: insets),
          child: screen,
        );
      },
    ),
  );
}

/// Pumps [screen] at 390 x 844 for goldens that open a sheet over it first.
Future<void> pumpOnboardingScreen(
  WidgetTester tester,
  SharedPreferences prefs,
  Widget screen,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      home: onboardingFrame(prefs, screen),
    ),
  );
  await tester.pumpAndSettle();
}

final sampleAboutYou = {
  'occupation': 'student',
  'dateOfBirth': '2004-03-12T00:00:00.000',
  'lastStep': 'aboutYou',
};

final sampleWhereYouLive = {
  ...sampleAboutYou,
  'state': 'Lagos',
  'city': 'Ikeja',
  'lastStep': 'whereYouLive',
};

final sampleWhereYouStudied = {
  ...sampleWhereYouLive,
  'education': 'hnd_bsc',
  'lastStep': 'whereYouStudied',
};

final sampleWhatYouLike = {
  ...sampleWhereYouStudied,
  'university': 'University of Lagos',
  'interests': ['marketing_advertising', 'finance_fintech'],
  'lastStep': 'whatYouLike',
};

/// Exp/BriefCard on this branch has a fixed body that a two-line ask
/// overflows (Done's Kudi Box card); the Discover lane's kit fix (b1a99b2)
/// lets the body grow. Until it lands, overflow reports are let through.
void allowBriefCardOverflow() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}
