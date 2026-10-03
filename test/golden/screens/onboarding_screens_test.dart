import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/features/onboarding/about_you_screen.dart';
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

  testWidgets('188:8255 Step 2 Where you are', (tester) async {
    final prefs = await onboardingPrefs(draft: sampleWhereYouLive);
    await expectGolden(
      tester,
      'onboarding_where_you_live',
      onboardingFrame(prefs, const WhereYouLiveScreen()),
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

  testWidgets('188:8340 Step 2 University search', (tester) async {
    final prefs = await onboardingPrefs(draft: sampleWhereYouStudied);
    await pumpOnboardingScreen(tester, prefs, const WhereYouStudiedScreen());
    await tester.tap(find.text('Search universities'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Lag');
    await tester.pumpAndSettle();
    await tester.tap(find.text('University of Lagos'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/onboarding_university_search.png'),
    );
  });

  testWidgets('City sheet over Where you are', (tester) async {
    final prefs = await onboardingPrefs(draft: sampleWhereYouLive);
    await pumpOnboardingScreen(tester, prefs, const WhereYouLiveScreen());
    await tester.tap(find.text('Ikeja'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/onboarding_city_sheet.png'),
    );
  });

  testWidgets('City sheet with a name the list does not have', (tester) async {
    final prefs = await onboardingPrefs(draft: sampleWhereYouLive);
    await pumpOnboardingScreen(tester, prefs, const WhereYouLiveScreen());
    await tester.tap(find.text('Ikeja'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ilupeju');
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/onboarding_city_sheet_add_mine.png'),
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
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/onboarding_home_setup_nudge.png'),
    );
  });
}
