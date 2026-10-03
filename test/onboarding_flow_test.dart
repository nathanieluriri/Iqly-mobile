import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/app.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/entry/notifications_ask_screen.dart';
import 'package:iqly_mobile/features/onboarding/about_you_screen.dart';
import 'package:iqly_mobile/features/onboarding/done_screen.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_sheets.dart';
import 'package:iqly_mobile/features/onboarding/resume_screen.dart';
import 'package:iqly_mobile/features/onboarding/welcome_screen.dart';
import 'package:iqly_mobile/features/onboarding/what_you_like_screen.dart';
import 'package:iqly_mobile/features/onboarding/where_you_live_screen.dart';
import 'package:iqly_mobile/features/onboarding/where_you_studied_screen.dart';
import 'package:iqly_mobile/ui/next_fab.dart';
import 'package:iqly_mobile/ui/tip_card.dart';
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
        repositoryProvider.overrideWithValue(DemoRepository(DemoData())),
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
    expect(_fab(tester), IqNextFabState.disabled);
    await _tap(tester, find.text('Select city'));
    expect(find.byType(CitySheet), findsOneWidget);
    expect(find.text('24 CITIES'), findsOneWidget);
    await _tap(tester, find.text('Ikeja'));
    await _tap(tester, find.text('Use this'));
    expect(find.byType(CitySheet), findsNothing);
    expect(find.text('Ikeja'), findsOneWidget);
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
    expect(service.saved?.state, 'Lagos');
    expect(service.saved?.city, 'Ikeja');
    expect(service.saved?.university, 'University of Lagos');
    expect(service.saved?.interests, [
      'marketing_advertising',
      'finance_fintech',
    ]);

    await _tap(tester, find.text('Continue'));
    expect(find.byType(NotificationsAskScreen), findsOneWidget);
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
    expect(find.byType(IqTipCard), findsOneWidget);
    await _tap(tester, find.text('OK, got it'));
    expect(find.byType(IqTipCard), findsNothing);
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

  group('city', () {
    Future<SharedPreferences> openWhereYouLive(
      WidgetTester tester,
      Map<String, Object?> draft,
    ) async {
      final (prefs, _) = await _launch(
        tester,
        draft: {'occupation': 'student', 'lastStep': 'whereYouLive', ...draft},
      );
      await _tap(tester, find.text('Continue'));
      expect(find.byType(WhereYouLiveScreen), findsOneWidget);
      return prefs;
    }

    Map<String, Object?> saved(SharedPreferences prefs) =>
        jsonDecode(prefs.getString('onboarding.draft')!)
            as Map<String, Object?>;

    Finder sheetList(Type sheet) => find.descendant(
      of: find.descendant(
        of: find.byType(sheet),
        matching: find.byType(ListView),
      ),
      matching: find.byType(Scrollable),
    );

    testWidgets('with no state, CITY asks for the state, then the city', (
      tester,
    ) async {
      final prefs = await openWhereYouLive(tester, {});
      await _tap(tester, find.text('Select city'));
      expect(find.byType(OptionSheet), findsOneWidget);
      expect(find.text('State of residence'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Lagos'),
        200,
        scrollable: sheetList(OptionSheet),
      );
      await _tap(tester, find.text('Lagos'));
      expect(saved(prefs)['state'], 'Lagos');

      expect(find.byType(OptionSheet), findsNothing);
      expect(find.byType(CitySheet), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Yaba'),
        200,
        scrollable: sheetList(CitySheet),
      );
      await _tap(tester, find.text('Yaba'));
      await _tap(tester, find.text('Use this'));
      expect(find.text('Lagos'), findsOneWidget);
      expect(find.text('Yaba'), findsOneWidget);
      expect(saved(prefs)['city'], 'Yaba');
      expect(_fab(tester), IqNextFabState.enabled);
    });

    testWidgets('a city the list does not have is added as typed', (
      tester,
    ) async {
      final prefs = await openWhereYouLive(tester, {'state': 'Lagos'});
      await _tap(tester, find.text('Select city'));

      await tester.enterText(find.byType(TextField), 'ikeja');
      await tester.pumpAndSettle();
      expect(find.text('1 MATCH'), findsOneWidget);
      expect(find.text('Add mine'), findsNothing);

      await tester.enterText(find.byType(TextField), ' Ilupeju ');
      await tester.pumpAndSettle();
      expect(find.text('No city found.'), findsOneWidget);
      expect(find.textContaining('MATCH'), findsNothing);
      await _tap(tester, find.text('Add mine'));

      expect(find.byType(CitySheet), findsNothing);
      expect(find.text('Ilupeju'), findsOneWidget);
      expect(saved(prefs)['city'], 'Ilupeju');
    });

    testWidgets('a saved free-text city stays until the state changes', (
      tester,
    ) async {
      final prefs = await openWhereYouLive(tester, {
        'state': 'Lagos',
        'city': 'Ilupeju',
      });
      expect(find.text('Ilupeju'), findsOneWidget);
      expect(_fab(tester), IqNextFabState.enabled);

      final inSheet = find.descendant(
        of: find.byType(OptionSheet),
        matching: find.text('Lagos'),
      );
      await _tap(tester, find.text('Lagos'));
      await tester.scrollUntilVisible(
        inSheet,
        200,
        scrollable: sheetList(OptionSheet),
      );
      await _tap(tester, inSheet);
      expect(find.text('Ilupeju'), findsOneWidget);

      await _tap(tester, find.text('Lagos'));
      await tester.scrollUntilVisible(
        find.text('Ogun'),
        200,
        scrollable: sheetList(OptionSheet),
      );
      await _tap(tester, find.text('Ogun'));
      expect(find.text('Select city'), findsOneWidget);
      expect(saved(prefs)['city'], '');
      expect(_fab(tester), IqNextFabState.disabled);
    });

    testWidgets('reduced motion: the sheet and the values arrive in place', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await openWhereYouLive(tester, {'state': 'Lagos'});
      await tester.tap(find.text('Select city'));
      // The sheet route's first frame lays out offstage for heroes.
      await tester.pump();
      await tester.pump();
      expect(tester.getTopLeft(find.byType(CitySheet)).dy, 120);

      await tester.tap(find.text('Ikeja'));
      await tester.pump();
      await tester.tap(find.text('Use this'));
      await tester.pump();
      await tester.pump(IqDurations.crossfade);
      expect(find.byType(CitySheet), findsNothing);
      expect(find.text('Select city'), findsNothing);
      expect(find.text('Ikeja'), findsOneWidget);
    });
  });
}
