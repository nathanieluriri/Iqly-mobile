import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/app.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/onboarding/about_you_screen.dart';
import 'package:iqly_mobile/features/onboarding/done_screen.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_sheets.dart';
import 'package:iqly_mobile/features/onboarding/resume_screen.dart';
import 'package:iqly_mobile/features/onboarding/welcome_screen.dart';
import 'package:iqly_mobile/features/onboarding/what_you_like_screen.dart';
import 'package:iqly_mobile/features/onboarding/where_you_live_screen.dart';
import 'package:iqly_mobile/features/onboarding/where_you_studied_screen.dart';
import 'package:iqly_mobile/ui/next_fab.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingService implements OnboardingService {
  OnboardingProfile? saved;

  @override
  Future<void> saveProfile(OnboardingProfile profile) async => saved = profile;
}

Future<(SharedPreferences, _RecordingService)> _launch(
  WidgetTester tester, {
  Map<String, Object?>? draft,
}) async {
  SharedPreferences.setMockInitialValues({
    'session.signedIn': true,
    if (draft != null) 'onboarding.draft': jsonEncode(draft),
  });
  final prefs = await SharedPreferences.getInstance();
  final service = _RecordingService();
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        onboardingServiceProvider.overrideWithValue(service),
      ],
      child: const IqlyApp(),
    ),
  );
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  return (prefs, service);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

IqNextFabState _fab(WidgetTester tester) =>
    tester.widget<IqNextFab>(find.byType(IqNextFab)).state;

void main() {
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  testWidgets('first run walks Welcome to Done and the notifications ask', (
    tester,
  ) async {
    final (prefs, service) = await _launch(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);

    await _tap(tester, find.text('Start'));
    expect(find.byType(AboutYouScreen), findsOneWidget);
    expect(_fab(tester), IqNextFabState.disabled);
    await _tap(tester, find.text('Student'));
    expect(_fab(tester), IqNextFabState.enabled);
    expect(find.bySemanticsLabel('Saved'), findsOneWidget);
    await _tap(tester, find.byType(IqNextFab));

    expect(find.byType(WhereYouLiveScreen), findsOneWidget);
    await _tap(tester, find.text('Select state'));
    await tester.scrollUntilVisible(
      find.text('Lagos'),
      200,
      scrollable: find.descendant(
        of: find.byType(OptionSheet),
        matching: find.byType(Scrollable),
      ),
    );
    await _tap(tester, find.text('Lagos'));
    await tester.enterText(find.byType(TextField), 'Ikeja');
    await tester.pumpAndSettle();
    expect(_fab(tester), IqNextFabState.enabled);
    await _tap(tester, find.byType(IqNextFab));

    expect(find.byType(WhereYouStudiedScreen), findsOneWidget);
    await _tap(tester, find.text('Select…'));
    await _tap(tester, find.text('HND / BSc'));
    await _tap(tester, find.text('Search universities'));
    expect(find.byType(UniversitySheet), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Lag');
    await tester.pumpAndSettle();
    expect(find.text('5 MATCHES'), findsOneWidget);
    await _tap(tester, find.text('University of Lagos'));
    await _tap(tester, find.text('Use this'));

    expect(find.byType(WhatYouLikeScreen), findsOneWidget);
    await _tap(tester, find.text('Marketing & advertising'));
    expect(_fab(tester), IqNextFabState.disabled);
    await _tap(tester, find.text('Finance & fintech'));
    expect(_fab(tester), IqNextFabState.enabled);
    await _tap(tester, find.byType(IqNextFab));

    expect(find.byType(DoneScreen), findsOneWidget);
    expect(find.text('Nice one, Adaeze'), findsOneWidget);
    expect(prefs.getBool('session.onboardingDone'), isTrue);
    expect(service.saved?.university, 'University of Lagos');
    expect(service.saved?.interests, [
      'marketing_advertising',
      'finance_fintech',
    ]);

    await _tap(tester, find.text('Continue'));
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('reopening mid-flow lands on Resume', (tester) async {
    await _launch(
      tester,
      draft: {'occupation': 'student', 'lastStep': 'whereYouLive'},
    );
    expect(find.byType(ResumeScreen), findsOneWidget);
    expect(find.text('Next: Where you live'), findsOneWidget);
    await _tap(tester, find.text('Continue'));
    expect(find.byType(WhereYouLiveScreen), findsOneWidget);
  });

  testWidgets('Start over clears the answers', (tester) async {
    await _launch(
      tester,
      draft: {'occupation': 'student', 'lastStep': 'whereYouLive'},
    );
    await _tap(tester, find.text('Start over'));
    expect(find.byType(AboutYouScreen), findsOneWidget);
    expect(_fab(tester), IqNextFabState.disabled);
  });

  testWidgets('Skip for now lands on Discover with the setup nudge', (
    tester,
  ) async {
    await _launch(tester);
    await _tap(tester, find.text('Skip for now'));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Finish setting up'), findsOneWidget);
    expect(find.text('3 steps left'), findsOneWidget);
    await _tap(tester, find.text('Finish setting up'));
    expect(find.byType(AboutYouScreen), findsOneWidget);
  });

  testWidgets('skip works on every step', (tester) async {
    await _launch(tester);
    await _tap(tester, find.text('Start'));
    for (final screen in [
      AboutYouScreen,
      WhereYouLiveScreen,
      WhatYouLikeScreen,
    ]) {
      expect(find.byType(screen), findsOneWidget);
      await _tap(tester, find.text('Skip'));
    }
    expect(find.byType(DoneScreen), findsOneWidget);
  });
}
