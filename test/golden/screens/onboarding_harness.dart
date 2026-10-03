import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iqly_mobile/core/session.dart';
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

final sampleAboutYou = {'occupation': 'student', 'lastStep': 'aboutYou'};

final sampleWhereYouLive = {
  'occupation': 'student',
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
