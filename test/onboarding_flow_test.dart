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
import 'package:iqly_mobile/features/onboarding/add_university_screen.dart';
import 'package:iqly_mobile/features/onboarding/done_screen.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_sheets.dart';
import 'package:iqly_mobile/features/onboarding/resume_screen.dart';
import 'package:iqly_mobile/features/onboarding/welcome_screen.dart';
import 'package:iqly_mobile/features/onboarding/what_you_like_screen.dart';
import 'package:iqly_mobile/features/onboarding/where_you_live_screen.dart';
import 'package:iqly_mobile/features/onboarding/where_you_studied_screen.dart';
import 'package:iqly_mobile/ui/button.dart';
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

/// Whether the step's primary button (Continue, Finish) is on.
bool _nextOn(WidgetTester tester) => !tester
    .widget<IqButton>(
      find.byWidgetPredicate(
        (w) => w is IqButton && w.kind == IqButtonKind.primary,
      ),
    )
    .disabled;

const _aboutYou = {
  'occupation': 'student',
  'dateOfBirth': '2004-03-12T00:00:00.000',
};

bool _buttonOn(WidgetTester tester, String label) =>
    !tester.widget<IqButton>(find.widgetWithText(IqButton, label)).disabled;

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
    expect(_nextOn(tester), isFalse);
    await _tap(tester, find.text('Student'));
    expect(_nextOn(tester), isFalse);
    await _tap(tester, find.text('Select…'));
    await _tap(tester, find.text('Use this'));
    expect(_nextOn(tester), isTrue);
    await _tap(tester, find.text('Continue'));

    expect(find.byType(WhereYouLiveScreen), findsOneWidget);
    await _tap(tester, find.text('Select state'));
    await _tap(tester, find.text('Lagos'));
    await _tap(tester, find.text('Use this'));
    expect(_nextOn(tester), isFalse);
    await _tap(tester, find.text('Select city'));
    expect(find.byType(CitySheet), findsOneWidget);
    await _tap(tester, find.text('Ikeja'));
    await _tap(tester, find.text('Use this'));
    expect(find.byType(CitySheet), findsNothing);
    expect(find.text('Ikeja'), findsOneWidget);
    expect(_nextOn(tester), isTrue);
    await tester.enterText(find.byType(TextField), '+234 803 000 0000');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Continue'));

    expect(find.byType(WhereYouStudiedScreen), findsOneWidget);
    await _tap(tester, find.text('Select…'));
    await _tap(tester, find.text('HND / BSc'));
    await _tap(tester, find.text('Use this'));
    await _tap(tester, find.text('Search universities'));
    expect(find.byType(UniversitySheet), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Lag');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('University of Lagos'));
    await _tap(tester, find.text('Use this'));

    expect(find.byType(WhatYouLikeScreen), findsOneWidget);
    await _tap(tester, find.text('Marketing & advertising'));
    expect(_nextOn(tester), isFalse);
    await _tap(tester, find.text('Finance & fintech'));
    expect(_nextOn(tester), isTrue);
    await _tap(tester, find.text('Finish'));

    expect(find.byType(DoneScreen), findsOneWidget);
    expect(find.text('Nice one, Adaeze'), findsOneWidget);
    expect(prefs.getBool('session.onboardingDone'), isTrue);
    expect(service.saved?.occupation, 'student');
    expect(service.saved?.dateOfBirth, isNotNull);
    expect(service.saved?.state, 'Lagos');
    expect(service.saved?.city, 'Ikeja');
    expect(service.saved?.phone, '+234 803 000 0000');
    expect(service.saved?.education, 'hnd_bsc');
    expect(service.saved?.university, 'University of Lagos');
    expect(service.saved?.interests, [
      'marketing_advertising',
      'finance_fintech',
    ]);

    await _tap(tester, find.text('Go to Discover'));
    expect(find.byType(NotificationsAskScreen), findsOneWidget);
  });

  testWidgets('a tap on the step puts the phone keypad away, so Continue '
      'can be reached', (tester) async {
    await _launch(
      tester,
      draft: {
        ..._aboutYou,
        'state': 'Lagos',
        'city': 'Ikeja',
        'lastStep': 'whereYouLive',
      },
    );
    await _tap(tester, find.text('Continue'));
    expect(find.byType(WhereYouLiveScreen), findsOneWidget);
    await tester.showKeyboard(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.text('Where do you live?'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('under 18 is blocked on About you (480:20079)', (tester) async {
    await _launch(
      tester,
      draft: {
        ..._aboutYou,
        'dateOfBirth': '2012-01-01T00:00:00.000',
        'lastStep': 'aboutYou',
      },
    );
    await _tap(tester, find.text('Continue'));
    expect(find.byType(AboutYouScreen), findsOneWidget);
    expect(find.text(AboutYouScreen.underAge), findsOneWidget);
    expect(find.text('Under 18'), findsOneWidget);
    expect(_nextOn(tester), isFalse);
  });

  testWidgets('Add my university opens the one-field page and the typed name '
      'comes back as the university (480:20477)', (tester) async {
    await _launch(
      tester,
      draft: {
        ..._aboutYou,
        'state': 'Lagos',
        'city': 'Ikeja',
        'education': 'hnd_bsc',
        'lastStep': 'whereYouStudied',
      },
    );
    await _tap(tester, find.text('Continue'));
    expect(find.byType(WhereYouStudiedScreen), findsOneWidget);
    await _tap(tester, find.text('Search universities'));
    await tester.enterText(find.byType(TextField), 'Caleb University');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Add my university'));
    expect(find.byType(AddUniversityScreen), findsOneWidget);
    expect(find.text('Caleb University'), findsOneWidget);
    await _tap(tester, find.text('Add it'));
    expect(find.byType(WhereYouStudiedScreen), findsOneWidget);
    expect(find.text('Caleb University'), findsOneWidget);
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
    await _launch(tester, draft: {..._aboutYou, 'lastStep': 'whereYouLive'});
    await _tap(tester, find.text('Start over'));
    expect(find.byType(AboutYouScreen), findsOneWidget);
    expect(_nextOn(tester), isFalse);
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

  testWidgets('Skip for now opens the next step only, and back returns to '
      'the opener', (tester) async {
    await _launch(tester);
    await _tap(tester, find.text('Start'));
    for (final screen in [
      AboutYouScreen,
      WhereYouLiveScreen,
      WhereYouStudiedScreen,
    ]) {
      expect(find.byType(screen), findsOneWidget);
      await _tap(tester, find.text('Skip for now'));
    }
    expect(find.byType(WhatYouLikeScreen), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(WhereYouStudiedScreen), findsOneWidget);
    await _tap(tester, find.text('Skip for now'));
    await _tap(tester, find.text('Skip for now'));
    expect(find.byType(DoneScreen), findsOneWidget);
  });

  group('city', () {
    Future<SharedPreferences> openWhereYouLive(
      WidgetTester tester,
      Map<String, Object?> draft,
    ) async {
      final (prefs, _) = await _launch(
        tester,
        draft: {..._aboutYou, 'lastStep': 'whereYouLive', ...draft},
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
      expect(
        find.descendant(
          of: find.byType(OptionSheet),
          matching: find.text('State'),
        ),
        findsOneWidget,
      );
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
      expect(_nextOn(tester), isTrue);
    });

    testWidgets('a city the list does not have is added as typed', (
      tester,
    ) async {
      final prefs = await openWhereYouLive(tester, {'state': 'Lagos'});
      await _tap(tester, find.text('Select city'));

      expect(_buttonOn(tester, 'Add my city'), isFalse);
      await tester.enterText(find.byType(TextField).last, 'ikeja');
      await tester.pumpAndSettle();
      expect(find.text('Ikeja'), findsOneWidget);
      expect(_buttonOn(tester, 'Add my city'), isFalse);

      await tester.enterText(find.byType(TextField).last, ' Ilupeju ');
      await tester.pumpAndSettle();
      expect(find.text('No city found.'), findsOneWidget);
      expect(_buttonOn(tester, 'Add my city'), isTrue);
      await _tap(tester, find.text('Add my city'));

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
      expect(_nextOn(tester), isTrue);

      final inSheet = find.descendant(
        of: find.byType(OptionSheet),
        matching: find.text('Lagos'),
      );
      await _tap(tester, find.text('Lagos'));
      await _tap(tester, inSheet);
      await _tap(tester, find.text('Use this'));
      expect(find.text('Ilupeju'), findsOneWidget);

      await _tap(tester, find.text('Lagos'));
      await tester.enterText(find.byType(TextField).last, 'Ogun');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Ogun', findRichText: true).last);
      await _tap(tester, find.text('Use this'));
      expect(find.text('Select city'), findsOneWidget);
      expect(saved(prefs)['city'], '');
      expect(_nextOn(tester), isFalse);
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
