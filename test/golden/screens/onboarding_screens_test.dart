import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/features/onboarding/about_you_screen.dart';
import 'package:iqly_mobile/features/onboarding/add_university_screen.dart';
import 'package:iqly_mobile/features/onboarding/done_screen.dart';
import 'package:iqly_mobile/features/onboarding/resume_screen.dart';
import 'package:iqly_mobile/features/onboarding/welcome_screen.dart';
import 'package:iqly_mobile/features/onboarding/what_you_like_screen.dart';
import 'package:iqly_mobile/features/onboarding/where_you_live_screen.dart';
import 'package:iqly_mobile/features/onboarding/where_you_studied_screen.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'onboarding_harness.dart';

void main() {
  setUpAll(loadAppFonts);
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  testWidgets('188:8099 Welcome', (tester) async {
    final prefs = await onboardingPrefs();
    await expectGolden(
      tester,
      'onboarding_welcome',
      onboardingFrame(prefs, const WelcomeScreen()),
    );
  });

  testWidgets('188:8171 Step 1 About you', (tester) async {
    final prefs = await onboardingPrefs(draft: sampleAboutYou);
    await expectGolden(
      tester,
      'onboarding_about_you',
      onboardingFrame(prefs, const AboutYouScreen()),
    );
  });

  testWidgets('480:20079 Step 1 under 18', (tester) async {
    final prefs = await onboardingPrefs(
      draft: {...sampleAboutYou, 'dateOfBirth': '2010-03-12T00:00:00.000'},
    );
    await expectGolden(
      tester,
      'onboarding_about_you_under_18',
      onboardingFrame(prefs, const AboutYouScreen()),
    );
  });

  testWidgets('188:8255 Step 2 Where you are', (tester) async {
    final prefs = await onboardingPrefs(draft: sampleWhereYouLive);
    await expectGolden(
      tester,
      'onboarding_where_you_live',
      onboardingFrame(prefs, const WhereYouLiveScreen()),
    );
  });

  testWidgets('480:20318 Step 2 State sheet', (tester) async {
    final prefs = await onboardingPrefs(draft: sampleWhereYouLive);
    await pumpOnboardingScreen(tester, prefs, const WhereYouLiveScreen());
    await tester.tap(find.text('Lagos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    await expectMatchesGolden(
      find.byType(MaterialApp),
      'goldens/onboarding_state_sheet.png',
    );
  });

  testWidgets('223:10826 Step 2 Where you studied', (tester) async {
    final prefs = await onboardingPrefs(draft: {...sampleWhereYouStudied});
    await expectGolden(
      tester,
      'onboarding_where_you_studied',
      onboardingFrame(prefs, const WhereYouStudiedScreen()),
    );
  });

  testWidgets('480:20164 Step 2 Education sheet', (tester) async {
    final prefs = await onboardingPrefs(draft: sampleWhereYouStudied);
    await pumpOnboardingScreen(tester, prefs, const WhereYouStudiedScreen());
    await tester.tap(find.text('HND / BSc'));
    await tester.pumpAndSettle();
    await expectMatchesGolden(
      find.byType(MaterialApp),
      'goldens/onboarding_education_sheet.png',
    );
  });

  testWidgets('480:20477 Add your university', (tester) async {
    final prefs = await onboardingPrefs(draft: sampleWhereYouStudied);
    await expectGolden(
      tester,
      'onboarding_add_university',
      onboardingFrame(
        prefs,
        const AddUniversityScreen(initialName: 'Caleb University'),
      ),
    );
  });

  testWidgets('188:8340 Step 2 University search', (tester) async {
    final prefs = await onboardingPrefs(draft: sampleWhereYouStudied);
    await pumpOnboardingScreen(tester, prefs, const WhereYouStudiedScreen());
    await tester.tap(find.text('Search universities'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Lag');
    await tester.pumpAndSettle();
    await tester.tap(find.text('University of Lagos'));
    await tester.pumpAndSettle();
    await expectMatchesGolden(
      find.byType(MaterialApp),
      'goldens/onboarding_university_search.png',
    );
  });

  testWidgets('City sheet over Where you are', (tester) async {
    final prefs = await onboardingPrefs(draft: sampleWhereYouLive);
    await pumpOnboardingScreen(tester, prefs, const WhereYouLiveScreen());
    await tester.tap(find.text('Ikeja'));
    await tester.pumpAndSettle();
    await expectMatchesGolden(
      find.byType(MaterialApp),
      'goldens/onboarding_city_sheet.png',
    );
  });

  testWidgets('City sheet with a name the list does not have', (tester) async {
    final prefs = await onboardingPrefs(draft: sampleWhereYouLive);
    await pumpOnboardingScreen(tester, prefs, const WhereYouLiveScreen());
    await tester.tap(find.text('Ikeja'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ilupeju');
    await tester.pumpAndSettle();
    await expectMatchesGolden(
      find.byType(MaterialApp),
      'goldens/onboarding_city_sheet_add_mine.png',
    );
  });

  testWidgets('188:8390 Step 3 What you like', (tester) async {
    final prefs = await onboardingPrefs(draft: sampleWhatYouLike);
    await expectGolden(
      tester,
      'onboarding_what_you_like',
      onboardingFrame(prefs, const WhatYouLikeScreen()),
    );
  });

  testWidgets('1284:90206 Step 3 a 4th pick', (tester) async {
    final prefs = await onboardingPrefs(
      draft: {
        ...sampleWhatYouLike,
        'interests': [
          'tech_gadgets',
          'marketing_advertising',
          'finance_fintech',
        ],
      },
    );
    await pumpOnboardingScreen(tester, prefs, const WhatYouLikeScreen());
    await tester.tap(find.text('Education'));
    await tester.pump();
    await tester.pump(IqDurations.mark + IqDurations.stagger);
    await expectMatchesGolden(
      find.byType(MaterialApp),
      'goldens/onboarding_what_you_like_refused.png',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('1284:90430 Step 3 Other', (tester) async {
    final prefs = await onboardingPrefs(
      draft: {
        ...sampleWhatYouLike,
        'interests': ['marketing_advertising', 'finance_fintech', 'other'],
        'otherInterest': 'Real estate',
      },
    );
    await expectGolden(
      tester,
      'onboarding_what_you_like_other',
      onboardingFrame(prefs, const WhatYouLikeScreen()),
    );
  });

  testWidgets('1284:90545 Step 2 Where you studied, SSCE', (tester) async {
    final prefs = await onboardingPrefs(
      draft: {...sampleWhereYouStudied, 'education': 'ssce'},
    );
    await expectGolden(
      tester,
      'onboarding_where_you_studied_ssce',
      onboardingFrame(prefs, const WhereYouStudiedScreen()),
    );
  });

  testWidgets('188:8443 Resume', (tester) async {
    final prefs = await onboardingPrefs(draft: sampleWhereYouLive);
    await expectGolden(
      tester,
      'onboarding_resume',
      onboardingFrame(prefs, const ResumeScreen()),
    );
  });

  testWidgets('188:8490 Done', (tester) async {
    final prefs = await onboardingPrefs(draft: sampleWhatYouLike);
    await expectGolden(
      tester,
      'onboarding_done',
      onboardingFrame(prefs, const DoneScreen()),
    );
  });

  testWidgets('188:8570 Home setup nudge', (tester) async {
    await pumpApp(
      tester,
      Routes.home,
      prefs: {
        ...signedInPrefs(onboardingDone: false),
        'onboarding.draft': jsonEncode({...sampleAboutYou, 'deferred': true}),
      },
    );
    await precacheImages(tester);
    await expectMatchesGolden(
      find.byType(MaterialApp),
      'goldens/onboarding_home_setup_nudge.png',
    );
  });
}
